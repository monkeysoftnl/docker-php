# Description: Makefile for building and pushing the docker images
VERSION_PREFIX ?= "v"
VERSION ?= $(VERSION_PREFIX)$(shell cat VERSION)
REGISTRY ?= ghcr.io/monkeysoftnl/docker-php

# Build and push the docker images
docker: docker-build docker-push

# Build the docker images
docker-build:
	docker buildx build --no-cache -t monkeysoft/php:8.4-nginx -t ${REGISTRY}/8.4-nginx --platform linux/amd64,linux/arm64 --load .
# Push the docker images
docker-push:
	docker push ${REGISTRY}/8.4-nginx
	docker push monkeysoft/php:8.4-nginx
