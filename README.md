# docker-php
Base docker image for PHP with Composer and NPM


## Tags
- `latest-apache`: `php:8.5-apache` (Debian), Apache with `.htaccess` and XSendFile.
- `latest-alpine`: `php:8.5-fpm-alpine` with nginx + php-fpm (supervisord). No `.htaccess`; use `X-Accel-Redirect` (or Symfony `trustXSendfileTypeHeader()`) instead of XSendFile.
- `latest-frankenphp`: `dunglas/frankenphp:php8.5-alpine` (Caddy + PHP, ZTS), runs as `www-data`. No `.htaccess`; no nginx/supervisord.
- `latest-fpm`: `php:8.5-fpm-alpine`, php-fpm only (port 9000). Pair with `latest-nginx`.
- `latest-nginx`: `nginx:alpine`, serves `/var/www/html/public` and proxies PHP to `FPM_HOST:FPM_PORT` (default `php:9000`).

Alpine and FrankenPHP images trust `X-Forwarded-For` from private networks (10/8, 172.16/12, 192.168/16), so `REMOTE_ADDR` is the real client behind NPM.

## Split nginx + php-fpm

```yaml
services:
  php:
    image: monkeysoft/php:latest-fpm
    volumes:
      - ./:/var/www/html
  nginx:
    image: monkeysoft/php:latest-nginx
    ports:
      - "8080:80"
    environment:
      FPM_HOST: php   # service name of the fpm container
    volumes:
      - ./:/var/www/html
    depends_on:
      - php
```
