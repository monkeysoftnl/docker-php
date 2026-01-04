FROM php:8.4-apache

COPY ./.docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./.docker/php/local.ini /usr/local/etc/php/conf.d/local.ini

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN apt-get update -y && apt-get upgrade -y
RUN apt-get install libapache2-mod-xsendfile -y && a2enmod xsendfile
RUN a2enmod remoteip && a2enmod headers && a2enmod rewrite
RUN apt-get install unzip tree nano libzip-dev libwebp-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev zlib1g-dev libicu-dev libwebp-dev -y
RUN apt-get install npm -y

RUN docker-php-ext-configure gd --with-webp --with-freetype --with-jpeg;

RUN docker-php-ext-install pdo_mysql \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install zip \
  && docker-php-ext-install exif \
  && docker-php-ext-install gd \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install intl \
  && docker-php-ext-install pcntl

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN chown -R www-data:www-data /var/www

USER www-data