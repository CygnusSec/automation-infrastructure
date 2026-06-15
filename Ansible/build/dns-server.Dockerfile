FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bind9 \
      bind9-utils \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/cache/bind /var/run/named \
    && chown -R bind:bind /var/cache/bind /var/run/named

EXPOSE 53/tcp 53/udp

CMD ["named", "-g", "-c", "/etc/bind/named.conf"]
