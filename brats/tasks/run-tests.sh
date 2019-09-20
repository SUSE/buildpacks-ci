#!/bin/bash

set -e -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "[CI] ${BUILDPACK} ${TEST_SUITE} tests have failed" > mail-output/subject-failed.txt

export BRATS_BUILDPACK=${BRATS_BUILDPACK}
export BRATS_BUILDPACK_VERSION=$(cat gh-release.buildpack/version)
export BRATS_BUILDPACK_URL=$(cat s3.suse-buildpacks-staging/url)
export BACKEND=ekcp
export QUIET_OUTPUT=true

pushd catapult
make recover tests-brats | tee ../mail-output/body-failed.txt
popd
