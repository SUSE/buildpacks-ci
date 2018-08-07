#!/bin/bash

set -e

pushd lftp.obs-buildpacks-staging-* > /dev/null
VERSION=$(ls *.src.rpm | sed -E 's/.*buildpack-([0-9.].+)-.*/\1/')
popd > /dev/null

if [[ $(cat s3.brats/brats.*) == $VERSION ]]; then
  echo -e "The buildpack with the version $VERSION was already tested, exiting ..."
  exit 1
else
  echo -n $VERSION > output/version
fi
