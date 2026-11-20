#!/usr/bin/env bash
#
# Build and push the multi-arch PHP images to Docker Hub and GHCR.
# Mirrors .github/workflows/docker.yml.
#
# Usage: ./build.sh [apache|alpine|frankenphp|fpm|nginx ...]   (default: all)
# Env:   PLATFORMS=linux/arm64,linux/amd64  NO_PUSH=1  USE_CACHE=1 (cache off by default)

set -euo pipefail
cd "$(dirname "$0")"

DOCKERHUB_REPO="monkeysoft/php"
GHCR_REPO="ghcr.io/monkeysoftnl/docker-php"
PLATFORMS="${PLATFORMS:-linux/arm64,linux/amd64}"
BUILDER="docker-php-builder"

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

for v in "${variants[@]}"; do
  echo "==> Building $v ($(dockerfile_for "$v")) for $PLATFORMS"
  args=(
    --builder "$BUILDER"
    --platform "$PLATFORMS"
    --file "$(dockerfile_for "$v")"
    --tag "$DOCKERHUB_REPO:8.5-$v"
    --tag "$GHCR_REPO:8.5-$v"
  )
  [[ -z "${USE_CACHE:-}" ]] && args+=(--no-cache)
  if [[ -n "${NO_PUSH:-}" ]]; then
    # Multi-arch images can't be loaded locally; just verify the build.
    args+=(--output type=cacheonly)
  else
    args+=(--push)
  fi
  docker buildx build "${args[@]}" .
done

echo "Done."
