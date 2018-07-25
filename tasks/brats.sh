#!/bin/bash

set -e

source ci/tasks/cf_login.sh

cd lftp.obs-buildpack-staging
rpm2cpio *.src.rpm | cpio -idmv
tar xf v*.tar.gz
cd cf-ruby-buildpack*

scripts/brats.sh
