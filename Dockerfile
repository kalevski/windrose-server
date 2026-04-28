# syntax=docker/dockerfile:1.7

FROM --platform=linux/amd64 debian:bookworm-slim

ARG WINE_VARIANT=stable
ARG DEPOT_DOWNLOADER_VERSION=3.4.0

ENV DEBIAN_FRONTEND=noninteractive \
    WINE_VARIANT=${WINE_VARIANT}

# ---- System packages + Wine ------------------------------------------------
RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg jq \
        unzip xz-utils \
        procps tini \
        gettext-base libicu72 \
        xvfb xauth \
        $( [ "$WINE_VARIANT" = "staging" ] && echo cabextract ); \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
        | gpg --dearmor -o /usr/share/keyrings/winehq-archive.key; \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ bookworm main" \
        > /etc/apt/sources.list.d/winehq.list; \
    apt-get update; \
    apt-get install -y --install-recommends "winehq-${WINE_VARIANT}"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ---- .NET 8 runtime (DepotDownloader needs it) ------------------------------
RUN set -eux; \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh --channel 8.0 --runtime dotnet --install-dir /usr/share/dotnet; \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet; \
    rm /tmp/dotnet-install.sh

# ---- DepotDownloader -------------------------------------------------------
RUN set -eux; \
    curl -fsSL \
        "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip" \
        -o /tmp/dd.zip; \
    mkdir -p /opt/depotdownloader; \
    unzip -q /tmp/dd.zip -d /opt/depotdownloader; \
    chmod +x /opt/depotdownloader/DepotDownloader; \
    rm /tmp/dd.zip

# ---- winetricks (only used for staging vcrun) ------------------------------
RUN set -eux; \
    if [ "$WINE_VARIANT" = "staging" ]; then \
        curl -fsSL "https://raw.githubusercontent.com/Winetricks/winetricks/20240105/src/winetricks" \
            -o /usr/local/bin/winetricks; \
        chmod +x /usr/local/bin/winetricks; \
    fi

# ---- Unprivileged runtime user --------------------------------------------
RUN useradd -m -s /bin/bash -u 1000 steam

# ---- Wine prefix initialisation -------------------------------------------
ENV HOME=/home/steam \
    WINEPREFIX=/home/steam/.wine \
    WINEARCH=win64 \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY=:0 \
    UPDATE_ON_START=true

RUN set -eux; \
    Xvfb :0 -screen 0 1024x768x16 & \
    sleep 2; \
    if [ "$WINE_VARIANT" = "staging" ]; then \
        su -l steam -c "WINEPREFIX=/home/steam/.wine WINEARCH=win64 winetricks -q win10 vcrun2022"; \
    else \
        su -l steam -c "WINEPREFIX=/home/steam/.wine WINEARCH=win64 winecfg -v win10 >/dev/null 2>&1 || true; wineboot --init >/dev/null 2>&1"; \
    fi; \
    kill %1 2>/dev/null || true

# ---- App ------------------------------------------------------------------
COPY --chown=steam:steam scripts/ /home/steam/server/
COPY motd /etc/motd

RUN mkdir -p /home/steam/server-files && \
    chmod +x /home/steam/server/*.sh && \
    chown -R steam:steam /home/steam/server-files

VOLUME ["/home/steam/server-files"]
WORKDIR /home/steam/server
EXPOSE 7777/udp 7777/tcp

HEALTHCHECK --start-period=5m --interval=30s --timeout=10s \
    CMD pgrep -f WindroseServer-Win64-Shipping.exe >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/home/steam/server/entrypoint.sh"]

LABEL org.opencontainers.image.title="windrose" \
      org.opencontainers.image.description="Windrose dedicated server running under Wine on Linux." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/kalevski/windrose-docker" \
      org.opencontainers.image.url="https://github.com/kalevski/windrose-docker"
