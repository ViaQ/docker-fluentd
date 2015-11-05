#!/bin/sh

set -ex
prefix=${PREFIX:-${1:-bitscout/}}
version=${VERSION:-${2:-latest}}
docker build -t "${prefix}fluentd:${version}" .

if [ -n "${PUSH:-$3}" ]; then
	docker push "${prefix}fluentd:${version}"
fi
