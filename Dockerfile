ARG PHP_VERSION=8.5
FROM php:${PHP_VERSION}-apache

COPY ./.docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./.docker/php/local.ini /usr/local/etc/php/conf.d/local.ini

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Runtime packages, Apache modules and latest Node.js LTS via NodeSource (includes npm)
RUN set -eux; \
  apt-get update; \
  apt-get upgrade -y; \
  apt-get install -y --no-install-recommends \
    tree nano unzip curl ca-certificates imagemagick postgresql-client \
    libapache2-mod-xsendfile; \
  a2enmod xsendfile rewrite; \
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -; \
  apt-get install -y --no-install-recommends nodejs; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/*

# PHP extensions: build deps are purged afterwards, runtime libs are kept
RUN set -eux; \
  apt-get update; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS libzip-dev libwebp-dev libfreetype6-dev libjpeg62-turbo-dev \
    libpng-dev zlib1g-dev libicu-dev libmagickwand-dev libpq-dev; \
  docker-php-ext-configure gd --with-webp --with-freetype --with-jpeg; \
  docker-php-ext-install -j"$(nproc)" \
    pdo_mysql mysqli zip exif gd bcmath intl pdo_pgsql pgsql pcntl; \
  pecl install redis imagick; \
  docker-php-ext-enable redis imagick; \
  rm -rf /tmp/pear ~/.pearrc; \
  find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-unneeded {} + || true; \
  apt-mark auto '.*' > /dev/null; \
  [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
  find /usr/local -type f -executable -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | grep -v '^diversion by' \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual; \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/* /tmp/*; \
  php -m | grep -E '^(gd|imagick|intl|redis|zip|pdo_pgsql)$' | wc -l | grep -q '^6$'

# Set the correct permissions for the application files
RUN chown -R www-data:www-data /var/www

# Set Default User for Apache
USER www-data
