ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV SSH_USER=debian
ENV SSH_PASSWORD=debian
ENV SSH_PORT=22

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssh-server \
    tzdata \
    sudo \
    passwd \
    curl \
    unzip \
    wget \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /etc/ssh

COPY docker/entrypoint.sh /usr/bin/entrypoint.sh

RUN chmod +x /usr/bin/entrypoint.sh

VOLUME ["/etc/ssh", "/home", "/root", "/var/log", "/usr/local", "/opt", "/var/cache/apt/archives"]

EXPOSE 22

ENTRYPOINT ["bash", "/usr/bin/entrypoint.sh"]
