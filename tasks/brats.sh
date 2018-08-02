#!/bin/bash

set -e

pushd lftp.obs-buildpacks-staging > /dev/null
VERSION=$(ls *.src.rpm | sed -E 's/.*buildpack-([0-9.].+)-.*/\1/')
popd > /dev/null

if ls s3-buildpacks/*buildpack-v${VERSION}-*.zip > /dev/null 2>&1; then
  echo -e "The buildpack with the version $VERSION was already released, exiting ..."
  exit 1
fi

source ci/tasks/cf_login.sh

rm ruby-buildpack/manifest.yml ruby-buildpack/VERSION

cd lftp.obs-buildpacks-staging

rpm2cpio *.src.rpm | cpio -idmv
tar xf v*.tar.gz
cp cf-ruby-buildpack-*/manifest.yml ../ruby-buildpack/
cp cf-ruby-buildpack-*/VERSION ../ruby-buildpack/
cd ../ruby-buildpack

scripts/brats.sh
