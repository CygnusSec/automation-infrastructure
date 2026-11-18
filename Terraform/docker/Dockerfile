FROM ubuntu:24.04

ARG TERRAFORM_VERSION=1.8.5
ARG TARGETARCH

ENV LANG=C.UTF-8
ENV LC_CTYPE=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    openssh-client \
    unzip \
  && rm -rf /var/lib/apt/lists/*

RUN terraform_arch="${TARGETARCH:-$(dpkg --print-architecture)}" \
  && case "${terraform_arch}" in \
      amd64|arm64) ;; \
      *) echo "Unsupported Docker target architecture: ${terraform_arch}" >&2; exit 1 ;; \
    esac \
  && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" -o /tmp/terraform.zip \
  && unzip /tmp/terraform.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/terraform \
  && rm -f /tmp/terraform.zip

ENTRYPOINT ["terraform"]
CMD ["version"]
