ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION} AS production
ENV DEBIAN_FRONTEND=noninteractive JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    SAGETV_HOME=/opt/sagetv/server JAVA_MEM_MB=2048 PUID=99 PGID=100 TZ=America/Chicago \
    MIM_ENABLED=false MIM_RESET_FROM_IMAGE=false XMLTV_RESET_FROM_IMAGE=false COMSKIP_RESET_FROM_IMAGE=false \
    HARDWARE_DECODE=true GPU_VENDOR=auto OPT_GENTUNER=Y MINI_DISCOVERY_BIND_ADDRESS=auto \
    XMLTV_IMPORT_PLUGIN=xmltv.XMLTVImportPlugin SAGETV_CA_CERTS_DIR=/opt/sagetv/certs \
    VIBE_TEST_CONTROL=false OPT_COMMANDIR=N OPT_COMSKIP=Y OPT_SETPERMS=Y OPT_LIRC=N TINI_SUBREAPER=1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -e; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update; \
    installed=false; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends \
        bash ca-certificates coreutils ffmpeg findutils fontconfig gosu iproute2 \
        libasound2t64 libavc1394-0 libfreetype6 libgif7 libiec61883-0 \
        libharfbuzz0b libjpeg-turbo8 libnsl2 libpng16-16t64 libraw1394-11 libtiff6 \
        libva2 libva-drm2 libvpl2 libmfx-gen1.2 libx11-6 libxext6 libxi6 libxrender1 \
        libxtst6 intel-media-va-driver-non-free mesa-va-drivers mesa-vulkan-drivers openjdk-11-jre-headless \
        procps tini tzdata; then \
        installed=true; break; \
      fi; \
      echo "APT runtime install attempt ${attempt} failed; retrying" >&2; \
      apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update; \
      sleep 5; \
    done; \
    test "$installed" = true; \
    rm -rf /var/lib/apt/lists/*
RUN useradd --system --create-home --home-dir /opt/sagetv --shell /bin/bash sagetv \
 && mkdir -p /usr/local/share/sagetv-dist /opt/sagetv/server /var/media /var/mediaext /var/tv
COPY artifacts/sagetv-server-x86_64.tar.gz /tmp/core.tar.gz
COPY artifacts/ffmpeg-mim/ /usr/local/share/sagetv-options/ffmpeg-mim/
COPY artifacts/xmltv/ /usr/local/share/sagetv-options/xmltv/
RUN tar -xzf /tmp/core.tar.gz -C /usr/local/share/sagetv-dist && rm /tmp/core.tar.gz \
 && test -f /usr/local/share/sagetv-dist/Sage.jar
COPY modern/rootfs/ /
COPY resources/gentuner-1.0.1.tgz resources/commandir-1.0.3.1-amd64.tgz /usr/local/share/sagetv-options/
COPY sagetv-base/SYSTEM/sagetv_files/comskip/ /usr/local/share/sagetv-options/comskip/
RUN set -e; \
    seed_ids=/usr/local/share/sagetv-options/.seed-ids; \
    mkdir -p "$seed_ids"; \
    hash_tree() { \
      find "$1" -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1; \
    }; \
    hash_tree /usr/local/share/sagetv-dist > "$seed_ids/core.sha256"; \
    hash_tree /usr/local/share/sagetv-options/ffmpeg-mim > "$seed_ids/mim.sha256"; \
    hash_tree /usr/local/share/sagetv-options/xmltv > "$seed_ids/xmltv.sha256"; \
    hash_tree /usr/local/share/sagetv-options/comskip > "$seed_ids/comskip.sha256"; \
    sha256sum /usr/local/share/sagetv-options/gentuner-1.0.1.tgz | cut -d' ' -f1 > "$seed_ids/gentuner.sha256"; \
    sha256sum /usr/local/share/sagetv-options/commandir-1.0.3.1-amd64.tgz | cut -d' ' -f1 > "$seed_ids/commandir.sha256"; \
    chmod 0755 /usr/local/bin/sagetv-entrypoint /usr/local/bin/sagetv-supervisor /usr/local/bin/gpu-check /usr/local/bin/sagetv-options
ARG CORE_VERSION=9.2.10-u26-dev
ARG SOURCE_REVISION=unknown
ARG CORE_REVISION=unknown
ARG MIM_REVISION=unknown
ARG XMLTV_REVISION=unknown
ARG RUNTIME_ENVIRONMENT_FINGERPRINT=unknown
LABEL org.opencontainers.image.title="OpenSageTV Vibe Server" \
      org.opencontainers.image.version="${CORE_VERSION}" \
      org.opencontainers.image.source="https://github.com/opensagetv-vibe/opensagetv-vibe-container" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opensagetv.vibe.core.revision="${CORE_REVISION}" \
      org.opensagetv.vibe.ffmpeg-mim.revision="${MIM_REVISION}" \
      org.opensagetv.vibe.xmltv-import.revision="${XMLTV_REVISION}"
LABEL org.opensagetv.vibe.runtime-environment.fingerprint="${RUNTIME_ENVIRONMENT_FINGERPRINT}"
VOLUME ["/opt/sagetv", "/var/media", "/var/mediaext", "/var/tv", "/unraid"]
EXPOSE 8080 42024 7818 8270/udp 31100/udp 31099 16867/udp 16869/udp 16881
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD pgrep -f 'java.*sage.Sage' >/dev/null || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/sagetv-entrypoint"]

FROM production AS debug
USER root
RUN set -e; \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update; \
    installed=false; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends \
        binutils file gdb iputils-ping jq less lsof net-tools patchelf strace vainfo vim-tiny; then \
        installed=true; break; \
      fi; \
      echo "APT debug install attempt ${attempt} failed; retrying" >&2; \
      apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update; \
      sleep 5; \
    done; \
    test "$installed" = true; \
    rm -rf /var/lib/apt/lists/*
ENV SAGETV_DEBUG_IMAGE=true
