# docker-php
Base docker image for PHP with Composer and NPM


## Tags
Tags are `<php-version>-<variant>`, e.g. `8.5-apache`, `8.4-fpm`. Versions: `8.4`, `8.5`, `8.6` (a version is skipped until its upstream base image exists). `latest-<variant>` is kept as an alias for `8.5`.

- `<ver>-apache`: `php:<ver>-apache` (Debian), Apache with `.htaccess` and XSendFile.
- `<ver>-alpine`: `php:<ver>-fpm-alpine` with nginx + php-fpm (supervisord). No `.htaccess`; use `X-Accel-Redirect` (or Symfony `trustXSendfileTypeHeader()`) instead of XSendFile.
- `<ver>-frankenphp`: `dunglas/frankenphp:php<ver>-alpine` (Caddy + PHP, ZTS), runs as `www-data`. No `.htaccess`; no nginx/supervisord.
- `<ver>-fpm`: `php:<ver>-fpm-alpine`, php-fpm only (port 9000). Pair with `<ver>-nginx`.
- `<ver>-nginx`: `nginx:alpine`, serves `/var/www/html/public` and proxies PHP to `FPM_HOST:FPM_PORT` (default `php:9000`). Same image for every version; the tag only keeps it aligned with `-fpm`.

## Building

`./build.sh [variant ...]` builds and pushes all versions and variants (multi-arch). Env: `PHP_VERSIONS="8.4 8.5"`, `PLATFORMS`, `NO_PUSH=1`, `USE_CACHE=1`. The PHP version is passed to the Dockerfiles as `--build-arg PHP_VERSION`. CI (`.github/workflows/docker.yml`) builds the same matrix.

Alpine and FrankenPHP images trust `X-Forwarded-For` from private networks (10/8, 172.16/12, 192.168/16), so `REMOTE_ADDR` is the real client behind NPM.

## Split nginx + php-fpm

```yaml
services:
  php:
    image: monkeysoft/php:8.5-fpm
    volumes:
      - ./:/var/www/html
  nginx:
    image: monkeysoft/php:8.5-nginx
    ports:
      - "8080:80"
    environment:
      FPM_HOST: php   # service name of the fpm container
    volumes:
      - ./:/var/www/html
    depends_on:
      - php
```
