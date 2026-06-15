FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      chrony \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/chrony /var/log/chrony

EXPOSE 123/udp

CMD ["chronyd", "-d", "-f", "/etc/chrony/chrony.conf"]
