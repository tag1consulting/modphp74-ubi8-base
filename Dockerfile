# Builder image to compile dependencies, outputs are opied to new image
# and artifacts are discarded.
FROM registry.access.redhat.com/ubi8/ubi-minimal as builder

USER root

COPY build/ImageMagick-7.0.11-6.tar.gz /tmp/.

# Build and install ImageMagick to tmp folder (to be copied to final image)
RUN microdnf -y install tar \
    gzip \
    gcc \
    diffutils \
    make && \
    pushd /tmp && \
    tar -xzf ImageMagick-7.0.11-6.tar.gz && \
    pushd ImageMagick-7.0.11-6 && \
    ./configure --prefix /tmp/ImageMagickInstall --disable-dependency-tracking --disable-docs && \
    pushd /tmp/ImageMagick-7.0.11-6 && \
    make -j `nproc` install

# Install ImageMagick as php extension
RUN microdnf -y install php-pear \
    php-devel \
    php-pecl-zip \
    php-xmlrpc && \
    cp -r /tmp/ImageMagickInstall/* /usr/local && \
    echo '' | pecl install imagick && \
    echo "extension=imagick.so" >> /etc/php.d/30-imagick.ini


# define final image, copy imagemagick components from staged build.
FROM registry.access.redhat.com/ubi8/ubi-minimal

LABEL name="php74-ubi-minimal-base" \
      maintainer="support@tag1consulting.com" \
      vendor="Tag1 Consulting" \
      version="1.0" \
      release="1" \
      summary="Simple base docker image for running PHP sites, Drupal oriented"

ENV OPCACHE_MEMORY_CONSUMPTION 128
ENV OPCACHE_REVALIDATE_FREQ 60
ENV PHP_MEMORY_LIMIT 256M
ENV HTTPD_MAX_CONNECTIONS_PER_CHILD 2000
ENV DOCUMENTROOT "/"

USER root

# Install image magick from build stage
COPY --from=builder /tmp/ImageMagickInstall /usr/local

# Install imagemagick php extension and other installed extensions
COPY --from=builder /usr/lib64/php/modules /usr/lib64/php/modules

# Reinstall timezone data (required by php runtime)
# (ubi-minimal has tzdata, but removed /usr/share/zoneinfo to save space.)
RUN microdnf reinstall tzdata

# Install php 7.4 and httpd 2.4
RUN microdnf module reset php && \
    microdnf module enable php:7.4 \
    httpd:2.4 && \
    microdnf install php \
    httpd

RUN chown -R 1001:0 /run/httpd /etc/httpd/run /var/log/httpd

#Read XFF headers, note this is insecure if you are not sanitizing
#XFF in front of the container
RUN { \
    echo '<IfModule mod_remoteip.c>'; \
    echo '  RemoteIPHeader X-Forwarded-For'; \
    echo '</IfModule>'; \
  } > /etc/httpd/conf.d/remoteip.conf

#Correctly set SSL if we are terminated by it
RUN { \
    echo 'SetEnvIf X-Forwarded-Proto "https" HTTPS=on'; \
  } > /etc/httpd/conf.d/remote_ssl.conf

USER 1001
