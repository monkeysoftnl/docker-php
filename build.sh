#!/usr/bin/env bash
#
# Build and push the multi-arch PHP images to Docker Hub and GHCR.
# Mirrors .github/workflows/docker.yml.
#
# Tags: <php-version>-<variant>, e.g. 8.5-apache, 8.4-fpm.
#
# Usage: ./build.sh [apache|alpine|frankenphp|fpm|nginx ...]   (default: all)
# Env:   PHP_VERSIONS="8.4 8.5 8.6"  PLATFORMS=linux/arm64,linux/amd64
#        NO_PUSH=1  USE_CACHE=1 (cache off by default)
# Versions whose base image does not exist (yet) are skipped with a warning.

set -euo pipefail
cd "$(dirname "$0")"

DOCKERHUB_REPO="monkeysoft/php"
GHCR_REPO="ghcr.io/monkeysoftnl/docker-php"
PLATFORMS="${PLATFORMS:-linux/arm64,linux/amd64}"
BUILDER="docker-php-builder"
# shellcheck disable=SC2206
VERSIONS=(${PHP_VERSIONS:-8.4 8.5 8.6})

# bash 3.2 (macOS default) has no associative arrays
dockerfile_for() {
  case "$1" in
    apache) echo Dockerfile ;;
    alpine) echo Dockerfile.alpine ;;
    frankenphp) echo Dockerfile.frankenphp ;;
    fpm) echo Dockerfile.fpm ;;
    nginx) echo Dockerfile.nginx ;;
    *) return 1 ;;
  esac
}

# Base image per variant/version (used to skip versions that don't exist yet).
base_image_for() {
  case "$1" in
    apache) echo "php:$2-apache" ;;
    alpine|fpm) echo "php:$2-fpm-alpine" ;;
    frankenphp) echo "dunglas/frankenphp:php$2-alpine" ;;
    nginx) echo "nginx:alpine" ;;
  esac
}

variants=("$@")
[[ ${#variants[@]} -eq 0 ]] && variants=(apache alpine frankenphp fpm nginx)

for v in "${variants[@]}"; do
  dockerfile_for "$v" >/dev/null || { echo "Unknown variant: $v (use apache|alpine|frankenphp|fpm|nginx)" >&2; exit 1; }
done

# Multi-arch builds need a docker-container builder (default driver can't do it).
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
fi

if [[ -z "${NO_PUSH:-}" ]]; then
  echo "Make sure you are logged in: docker login && docker login ghcr.io"
fi

build() {
  local v="$1"; shift
  local versions=("$@")
  local args=(--builder "$BUILDER" --platform "$PLATFORMS" --file "$(dockerfile_for "$v")")
  local ver
  for ver in "${versions[@]}"; do
    args+=(--tag "$DOCKERHUB_REPO:$ver-$v" --tag "$GHCR_REPO:$ver-$v")
  done
  # nginx has no PHP; PHP_VERSION build-arg only for PHP variants.
  [[ "$v" != nginx ]] && args+=(--build-arg "PHP_VERSION=${versions[0]}")
  [[ -z "${USE_CACHE:-}" ]] && args+=(--no-cache)
  if [[ -n "${NO_PUSH:-}" ]]; then
    # Multi-arch images can't be loaded locally; just verify the build.
    args+=(--output type=cacheonly)
  else
    args+=(--push)
  fi
  echo "==> Building $v ($(dockerfile_for "$v")) for $PLATFORMS: ${versions[*]}"
  docker buildx build "${args[@]}" .
}

for v in "${variants[@]}"; do
  if [[ "$v" == nginx ]]; then
    # Same image for every PHP version: build once, tag per version.
    build nginx "${VERSIONS[@]}"
    continue
  fi
  for ver in "${VERSIONS[@]}"; do
    base="$(base_image_for "$v" "$ver")"
    if ! docker buildx imagetools inspect "$base" >/dev/null 2>&1; then
      echo "WARN: base image $base not found, skipping $ver-$v" >&2
      continue
    fi
    build "$v" "$ver"
  done
done

echo "Done."
