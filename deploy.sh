#!/bin/bash

common() {
	fly -t ${TARGET} set-pipeline -p ${2} -c <(erb ${1}/pipeline.yaml) -l ${CONCOURSE_SECRETS_FILE} && \
	fly -t ${TARGET} unpause-pipeline -p ${2} && \
	fly -t ${TARGET} expose-pipeline -p ${2}
}

brats() {
  common brats buildpacks-test-and-release
}

buildpacks() {
  common buildpacks buildpacks
}

java() {
  common java java-buildpacks
}


dotnet() {
  common dotnet dotnet-dependencies
}

if test -n "${CONCOURSE_SECRETS_FILE:-}"; then
    if test -r "${CONCOURSE_SECRETS_FILE:-}" ; then
        secrets_file="${CONCOURSE_SECRETS_FILE}"
    else
        printf "ERROR: Secrets file %s is not readable\n" "${CONCOURSE_SECRETS_FILE}" >&2
        exit 2
    fi
else
    echo "ERROR: CONCOURSE_SECRETS_FILE location is not set" >&2
    exit 3
fi

if [ -z "${TARGET}" ]; then
	echo "ERROR: No TARGET specified. Please set the TARGET env variable"
	exit 1
fi

case $1 in
brats)
	brats
  ;;
buildpacks)
	buildpacks
  ;;
java)
	java
  ;;
dotnet)
	dotnet
  ;;
*)
  echo "You didn't specify a pipeline to deploy. Available options: brats, buildpacks, java, dotnet"
	exit 1
  ;;
esac
