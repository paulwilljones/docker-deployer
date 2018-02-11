DBG_MAKEFILE ?=
ifeq ($(DBG_MAKEFILE),1)
	$(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
	$(warning ***** $(shell date))
else
	MAKEFLAGS += -s
endif

# Metadata for driving the build lives here.
META_DIR := .make
SHELL := /usr/bin/env bash

default: help

help:

	@echo "---> Help menu:"
	@echo ""
	@echo "Help output:"
	@echo "make help"
	@echo ""
	@echo "Install pre-commit hooks"
	@echo "make install-hooks"
	@echo ""
	@echo "Clean the repo of pre-commit hooks"
	@echo "make clean-hooks"
	@echo ""
	@echo "Run pre-commit hooks locally"
	@echo "make run-hooks"
	@echo ""

NAME := docker-deployer
REGISTRY := quay.io/paulwilljones
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_SHA := $(shell git log -1 --format=%h)
GIT_TAG := $(shell bash -c 'TAG=$$(git tag | tail -n1); echo "$${TAG:none}"')
GIT_MESSAGE := $(shell git -c log.showSignature=false log --max-count=1 --pretty=format:"%H")
CONTAINER_NAME := $(REGISTRY)/$(NAME):$(GIT_SHA)

export NAME REGISTRY BUILD_DATE GIT_SHA GIT_TAG GIT_MESSAGE CONTAINER_NAME

.PHONY: all help install-hooks clean-hooks run-hook build run

all: build run

install-hooks:
	pip install -r requirements-pre-commit.txt
	pip install --upgrade pre-commit
	pre-commit install --install-hooks
	pre-commit autoupdate

clean-hooks:
	pre-commit clean
	pre-commit uninstall

run-hooks: install-hooks
	pre-commit run --all-files

build:
	docker build -t "$(CONTAINER_NAME)" \
		--rm=true \
		--file=Dockerfile \
		.
	docker tag "$(CONTAINER_NAME)" $(REGISTRY)/$(NAME):latest

test: build
	#docker build -t ansible_test tests/ansible_target/Dockerfile.test .
	docker run -d --expose=22 --name ansible_target \
		-v ~/.ssh/id_rsa.pub:/home/ubuntu/.ssh/authorized_keys philm/ansible_target:latest

	docker run --rm -it \
		--name $(NAME) \
		--link ansible_target \
		-v ~/.ssh/id_rsa:/root/.ssh/id_rsa \
		-v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub \
		-v $(pwd):/ansible/playbooks \
		$(CONTAINER_NAME) \
		-i test/inventory

run: build
	docker run --rm -it --name $(NAME) \
		-v ~/.ssh/id_rsa:/root/.ssh/id_rsa \
		-v ~/.ssh/id_rsa.pub:/root.ssh/id_rsa.pub \
		$(CONTAINER_NAME) \
		ansible-playbook /etc/ansible/plays/playbook.yml \
		-i hosts \
		-u ${USER} \
		--private-key=/root/.ssh/id_rsa \
		--ask-sudo-pass
