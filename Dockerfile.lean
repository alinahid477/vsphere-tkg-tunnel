FROM debian:buster-slim

# culr (optional) for downloading/browsing stuff
# openssh-client (required) for creating ssh tunnel
# psmisc (optional) I needed it to test port binding after ssh tunnel (eg: netstat -ntlp | grep 6443)
# nano (required) buster-slim doesn't even have less. so I needed an editor to view/edit file (eg: /etc/hosts) 

RUN apt-get update && apt-get install -y \
	apt-transport-https \
	ca-certificates \
	curl \
	unzip \
    openssh-client \
	libdigest-sha-perl \
	psmisc \
	nano \
	less \
	net-tools \
	docker.io \
	sudo \
	&& curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
	&& chmod +x /usr/local/bin/kubectl

# COPY .ssh/id_rsa /root/.ssh/
# RUN chmod 600 $HOME/.ssh/id_rsa

RUN curl -o /usr/local/bin/jq -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
  	chmod +x /usr/local/bin/jq

RUN curl -L https://carvel.dev/install.sh | bash

# COPY tool/kubectl-vsphere /usr/local/bin/ 
# RUN chmod +x /usr/local/bin/kubectl-vsphere

# COPY binaries/tmc /usr/local/bin/ 
# RUN chmod +x /usr/local/bin/tmc



RUN useradd -m dev -d /home/dev -s /bin/bash && echo "dev:dev" | chpasswd && adduser dev sudo
RUN usermod -g docker dev
VOLUME [/var/run/docker.sock]
USER dev
WORKDIR /home/dev
ENV PATH="$PATH:/home/dev/.local/bin"
RUN echo $PATH
RUN mkdir -p $HOME/.ssh/
RUN mkdir -p $HOME/.kube/
RUN mkdir -p $HOME/binaries/
RUN mkdir -p $HOME/.local/bin

COPY --chown=1000 binaries/tanzu-cluster.v1alpha1.template /usr/local/ 
RUN chmod +x /usr/local/tanzu-cluster.v1alpha1.template

COPY --chown=1000 binaries/tanzu-cluster.v1alpha2.template /usr/local/ 
RUN chmod +x /usr/local/tanzu-cluster.v1alpha2.template

COPY --chown=1000 binaries/tanzu-cluster.volumeconfig.template /usr/local/ 
RUN chmod +x /usr/local/tanzu-cluster.volumeconfig.template

COPY --chown=1000 binaries/init.sh /usr/local/ 
RUN chmod +x /usr/local/init.sh
COPY --chown=1000 binaries/merlin.sh /usr/local/bin/merlin
RUN chmod +x /usr/local/bin/merlin

RUN ./usr/local/init.sh

CMD [ "/bin/bash"]