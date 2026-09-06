#!/usr/bin/env bash
echo "ERROR: historical registry publication is disabled in OpenSageTV Vibe" >&2
exit 2

docker login --username=jusjoken
docker push sagetvopen/sagetv-buildbase
