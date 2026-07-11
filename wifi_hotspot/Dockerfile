ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base:3.21
FROM ${BUILD_FROM}

RUN apk add --no-cache \
        dbus \
        hostapd \
        iproute2 \
        iptables \
        iw \
        networkmanager-cli

COPY rootfs /

RUN chmod a+x /etc/s6-overlay/scripts/* \
    && chmod a+x /etc/s6-overlay/s6-rc.d/hostapd/run \
    && chmod a+x /etc/s6-overlay/s6-rc.d/hostapd/finish

LABEL \
    io.hass.version="1.0.0" \
    io.hass.type="addon" \
    io.hass.arch="aarch64|armv7|amd64"
