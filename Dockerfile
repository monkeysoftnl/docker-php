FROM php:8.4-fpm-alpine

COPY ./.docker/php/local.ini /usr/local/etc/php/conf.d/local.ini

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN apk update
RUN apk add --no-cache tree nano libzip-dev freetype-dev libwebp-dev libjpeg-turbo-dev libpng-dev zlib-dev icu-dev
RUN apk add --no-cache npm

RUN docker-php-ext-install pdo_mysql \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install zip \
  && docker-php-ext-install exif \
  && docker-php-ext-install gd \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install intl \
  && docker-php-ext-install pcntl

# Set the correct permissions for the application files
RUN chown -R www-data:www-data /var/www

# Set Default User for FPM
USER www-data