FROM registry.access.redhat.com/ubi8/php-74:1-35

LABEL name="php-base-ubi-modphp74" \
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

RUN echo "enabled=0" >> /etc/yum/pluginconf.d/subscription-manager.conf
COPY build/ImageMagick-7.0.11-6.tar.gz /tmp/.
RUN pushd /tmp && \
    tar -xzf ImageMagick-7.0.11-6.tar.gz && \
    pushd ImageMagick-7.0.11-6 && \
    ./configure --prefix /usr/local && \
    make -j `nproc` install && \
    popd && \
    rm -rf  ImageMagick* && \
    popd

RUN dnf -y install php-pear \
    php-devel \
    php-pecl-zip \
    php-xmlrpc && \
    echo '' | pecl install imagick && \
    echo "extension=imagick.so" >> /etc/php.d/30-imagick.ini && \
    chown -R 1001:0 /run/httpd /etc/httpd/run /var/log/httpd

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
  && php /tmp/composer-setup.php --filename composer --install-dir /usr/local/bin

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

RUN rpm-file-permissions

USER 1001

ENTRYPOINT [ "/usr/libexec/s2i/run" ]
