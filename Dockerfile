# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.18
ARG S6_VERSION=2.2.0.3
ARG SAMBA_VERSION=4.18.5

FROM crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION}
ARG SAMBA_VERSION
RUN apk --update --no-cache add \
    bash \
    coreutils \
    jq \
    samba=${SAMBA_VERSION}-r0 \
    shadow \
    tzdata \
    yq \
  && rm -rf /tmp/*

COPY rootfs /

EXPOSE 445
VOLUME [ "/data" ]
ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD smbclient -L \\localhost -U % -m SMB3
