#!/bin/bash

set -e

source ci/tasks/cf_login.sh

rm ruby-buildpack/manifest.yml ruby-buildpack/VERSION

cd lftp.obs-buildpacks-staging
rpm2cpio *.src.rpm | cpio -idmv
tar xf v*.tar.gz
cp cf-ruby-buildpack-*/manifest.yml ../ruby-buildpack/
cp cf-ruby-buildpack-*/VERSION ../ruby-buildpack/
cd ../ruby-buildpack

scripts/brats.sh
