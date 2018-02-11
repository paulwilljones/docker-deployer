# Dockerfile for building Ansible 1.9 image for Alpine 3, with as few additional software as possible.
#
# @see https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md
#
# Version  1.0
#


# pull base image
FROM alpine:3.6

RUN echo "===> Installing sudo to emulate normal OS behavior..."  && \
    apk --update add sudo                                         && \
    echo "===> Adding Python runtime..."                          && \
    apk --update add python py-pip openssl ca-certificates        && \
    apk --update add --virtual build-dependencies \
                python-dev libffi-dev openssl-dev build-base      && \
    pip install --upgrade pip cffi                                && \
    echo "===> Installing Ansible..."                             && \
    pip install ansible                                           && \
    echo "===> Removing package list..."                          && \
    apk del build-dependencies                                    && \
    rm -rf /var/cache/apk/*                                       # && \
    # \
    # \
    # echo "===> Adding hosts for convenience..."  && \
    # mkdir -p /etc/ansible                        && \
    # echo 'localhost' > /etc/ansible/hosts

RUN mkdir -p /etc/ansible/roles /etc/ansible/plays
COPY plays/ /etc/ansible/plays/
COPY roles/ /etc/ansible/roles/
COPY hosts /etc/ansible/hosts
COPY requirements.yml /tmp/requirements.yml
#RUN echo "[local]" >> /etc/ansible/hosts && \
#  echo "localhost" >> /etc/ansible/hosts
WORKDIR /etc/ansible/

RUN ansible-galaxy install -r /tmp/requirements.yml

ENV INSTALL_MINIKUBE=false
ENV INSTALL_HELM=false
ENV INSTALL_APP=false
ENV APP_REPO=https://kubernetes-charts.storage.googleapis.com
ENV APP=stable

# default command: display Ansible version
CMD [ "ansible-playbook"]
#CMD [ "ansible-playbook", "/etc/ansible/plays/playbook.yml" ]

LABEL \
  org.label-schema.name="docker-deployer" \
  org.label-schema.docker.cmd="docker run -d -it --rm --name docker-deployer -v $(pwd):/etc/ansible -v requirements.yml:/tmp/requirements.yml quay.io/paulwilljones/docker-deployer /etc/ansible/plays/playbook.yml -vv"
