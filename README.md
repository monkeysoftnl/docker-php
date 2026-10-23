# docker-php
Base docker image for PHP with Composer and NPM


## Tags
- `latest-apache`: `php:8.5-apache` (Debian), Apache with `.htaccess` and XSendFile.
- `latest-alpine`: `php:8.5-fpm-alpine` with nginx + php-fpm (supervisord). No `.htaccess`; use `X-Accel-Redirect` (or Symfony `trustXSendfileTypeHeader()`) instead of XSendFile.
- `latest-frankenphp`: `dunglas/frankenphp:php8.5-alpine` (Caddy + PHP, ZTS), runs as `www-data`. No `.htaccess`; no nginx/supervisord.

Alpine and FrankenPHP images trust `X-Forwarded-For` from private networks (10/8, 172.16/12, 192.168/16), so `REMOTE_ADDR` is the real client behind NPM.
