# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.18
ARG SAMBA_VERSION=4.18.3

FROM alpine:${ALPINE_VERSION}
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

COPY entrypoint.sh /entrypoint.sh
ENV TZ=UTC

EXPOSE 445

VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "smbd", "-F", "--debug-stdout", "--no-process-group" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD smbclient -L \\localhost -U % -m SMB3
