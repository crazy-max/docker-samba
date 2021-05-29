ARG SAMBA_VERSION=4.13.8
ARG SAMBA_RELEASE=r0

FROM alpine:3.13
LABEL maintainer="CrazyMax"

ENV TZ="UTC"

ARG SAMBA_VERSION
ARG SAMBA_RELEASE
RUN apk --update --no-cache add \
    bash \
    coreutils \
    jq \
    samba=${SAMBA_VERSION}-${SAMBA_RELEASE} \
    shadow \
    tzdata \
    yq \
  && rm -rf /tmp/*

COPY entrypoint.sh /entrypoint.sh

EXPOSE 139 445

VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "smbd", "-FS", "--no-process-group" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD smbclient -L \\localhost -U % -m SMB3
