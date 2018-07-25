#!/bin/bash

set -e

source ci/tasks/cf_login.sh

cd lftp.obs-buildpacks-staging
rpm2cpio *.src.rpm | cpio -idmv
tar xf v*.tar.gz
mv cf-ruby-buildpack-*/manifest.yml ../ruby-buildpack/
cd ../ruby-buildpack

scripts/brats.sh
