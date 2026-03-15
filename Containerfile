# Immich Media Server - All-in-one container on ubi10-core
# Services: PostgreSQL, Valkey, Immich Server (Node.js)
# Build deps: libvips (source), pgvector (source), ffmpeg (RPMFusion)

# Extract Immich application from official image
FROM ghcr.io/immich-app/immich-server:release AS immich-source

# Build libvips from source — librsvg2-devel requires RHSM
FROM registry.access.redhat.com/ubi10/ubi-init:latest AS vips-build
RUN --mount=type=secret,id=RHSM_ACTIVATION_KEY \
    --mount=type=secret,id=RHSM_ORG_ID \
    subscription-manager register \
      --activationkey="$(cat /run/secrets/RHSM_ACTIVATION_KEY)" \
      --org="$(cat /run/secrets/RHSM_ORG_ID)" \
    && dnf install -y \
    gcc gcc-c++ make wget xz \
    meson ninja-build pkg-config \
    glib2-devel expat-devel \
    libjpeg-turbo-devel libpng-devel \
    libtiff-devel libwebp-devel \
    libexif-devel lcms2-devel \
    librsvg2-devel \
    && dnf clean all \
    && subscription-manager unregister \
    && cd /tmp \
    && wget https://github.com/libvips/libvips/releases/download/v8.15.2/vips-8.15.2.tar.xz \
    && tar xf vips-8.15.2.tar.xz \
    && cd vips-8.15.2 \
    && meson setup build --prefix=/usr/local --buildtype=release \
    && cd build \
    && ninja \
    && ninja install

# Build pgvector 0.7.4 from source — postgresql-server-devel requires RHSM
FROM registry.access.redhat.com/ubi10/ubi-init:latest AS pgvector-build
RUN --mount=type=secret,id=RHSM_ACTIVATION_KEY \
    --mount=type=secret,id=RHSM_ORG_ID \
    subscription-manager register \
      --activationkey="$(cat /run/secrets/RHSM_ACTIVATION_KEY)" \
      --org="$(cat /run/secrets/RHSM_ORG_ID)" \
    && dnf install -y \
    gcc gcc-c++ make wget \
    redhat-rpm-config \
    postgresql-server-devel \
    && dnf clean all \
    && subscription-manager unregister \
    && cd /tmp \
    && wget https://github.com/pgvector/pgvector/archive/refs/tags/v0.7.4.tar.gz \
    && tar xf v0.7.4.tar.gz \
    && cd pgvector-0.7.4 \
    && make \
    && make install DESTDIR=/pgvector-install

# Final image — inherits troubleshooting tools, systemd hardening from ubi10-core
FROM quay.io/crunchtools/ubi10-core:latest

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="Immich Media Server - All-in-one container on ubi10-core"

# Install EPEL and RPMFusion for full ffmpeg with codecs
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm && \
    dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-10.noarch.rpm

# postgresql-server requires RHSM
RUN --mount=type=secret,id=RHSM_ACTIVATION_KEY \
    --mount=type=secret,id=RHSM_ORG_ID \
    subscription-manager register \
      --activationkey="$(cat /run/secrets/RHSM_ACTIVATION_KEY)" \
      --org="$(cat /run/secrets/RHSM_ORG_ID)" \
    && dnf install -y \
      postgresql-server \
      postgresql-contrib \
      valkey \
      nodejs \
      npm \
      sudo \
      ca-certificates \
      glib2 expat \
      libjpeg-turbo libpng \
      libtiff libwebp \
      libexif lcms2 \
      librsvg2 \
      ffmpeg \
    && dnf clean all \
    && subscription-manager unregister

# Copy libvips from build stage
COPY --from=vips-build /usr/local/lib64/libvips* /usr/lib64/
COPY --from=vips-build /usr/local/lib64/pkgconfig/vips* /usr/lib64/pkgconfig/

# Copy pgvector 0.7.4 from build stage
COPY --from=pgvector-build /pgvector-install/usr/ /usr/

# Copy Immich application and geodata from official image
COPY --from=immich-source /usr/src/app /usr/src/app
COPY --from=immich-source /build /build

RUN ldconfig

# Create Immich user and set up directories
RUN useradd -r -s /bin/false immich && \
    mkdir -p /usr/src/app/upload && \
    chown -R immich:immich /usr/src/app

# Initialize PostgreSQL
RUN mkdir -p /var/lib/pgsql/data && \
    chown -R postgres:postgres /var/lib/pgsql && \
    sudo -u postgres /usr/bin/initdb -D /var/lib/pgsql/data

# Configure Valkey — bind to localhost only
RUN sed -i 's/^bind .*/bind 127.0.0.1/' /etc/valkey/valkey.conf

# Copy systemd units, scripts, and config
COPY rootfs/ /

# Enable services and make scripts executable
RUN chmod +x /usr/local/bin/init-immich-db.sh && \
    systemctl enable postgresql valkey immich-db-init immich-server

EXPOSE 2283

VOLUME ["/var/lib/pgsql/data", "/usr/src/app/upload"]
