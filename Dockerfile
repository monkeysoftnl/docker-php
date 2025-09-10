FROM php:8.4-fpm-alpine AS builder

# Install build dependencies
RUN apk add --no-cache $PHPIZE_DEPS \
    imagemagick-dev icu-dev zlib-dev jpeg-dev libpng-dev libzip-dev postgresql-dev libgomp linux-headers

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg
RUN docker-php-ext-install intl pcntl gd exif zip mysqli pgsql pdo pdo_mysql pdo_pgsql bcmath opcache

# Install imagick extension (workaround)
ARG IMAGICK_VERSION=3.8.0
#    && pecl install imagick-"$IMAGICK_VERSION" \
#    && docker-php-ext-enable imagick \
#    && apk del .imagick-deps
RUN curl -L -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/tags/${IMAGICK_VERSION}.tar.gz \
    && tar --strip-components=1 -xf /tmp/imagick.tar.gz \
    && sed -i 's/php_strtolower/zend_str_tolower/g' imagick.c \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini

# Clean up build dependencies
RUN apk del $PHPIZE_DEPS imagemagick-dev icu-dev zlib-dev jpeg-dev libpng-dev libzip-dev postgresql-dev libgomp 

FROM php:8.4-fpm-alpine
LABEL Maintainer="Stephan Eizinga <stephan@monkeysoft.nl"
LABEL Description="Docker image for running Nginx and PHP-FPM 8.4 on Alpine Linux"

# Setup document root
WORKDIR /var/www/html

# Install packages and remove default server definition
RUN apk add --no-cache \
  curl \
  nginx \
  supervisor

# Copy only the necessary files from the builder stage
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Install additional tools and required libraries
RUN apk add --no-cache libpng libpq zip jpeg libzip imagemagick \
    git curl sqlite nodejs npm nano ncdu openssh-client

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer


# RUN ln -s /usr/bin/php84 /usr/bin/php

# Configure nginx - http
COPY .docker/nginx/nginx.conf /etc/nginx/nginx.conf
# Configure nginx - default server
COPY .docker/nginx/conf.d /etc/nginx/conf.d/

# Configure PHP-FPM
ENV PHP_INI_DIR=/etc/php84
COPY .docker/php/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY .docker/php/local.ini ${PHP_INI_DIR}/conf.d/local.ini

# Configure supervisord
COPY .docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody:nobody /var/www/html /run /var/lib/nginx /var/log/nginx

# Switch to use a non-root user from here on
USER nobody

# Add application
# COPY --chown=nobody src/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1