#!/bin/bash

set -e

pushd lftp.obs-buildpacks-staging-* > /dev/null
VERSION=$(ls *.src.rpm | sed -E 's/.*buildpack-([0-9.].+)-.*/\1/')
BUILDPACK=$(ls *.src.rpm | sed -E 's/(.*buildpack-[0-9.].+)-.*/\1/')
popd > /dev/null

source ci/tasks/cf_login.sh

rm buildpack/manifest.yml buildpack/VERSION

cd lftp.obs-buildpacks-staging-*

rpm2cpio *.src.rpm | cpio -idmv
tar xf v*.tar.gz
cp *-buildpack-*/manifest.yml *-buildpack-*/VERSION ../buildpack/
cd ../buildpack

scripts/brats.sh

if [ $? -ne 0 ]; then
cat << EOF > mail-output/subject-failed.txt
${BUILDPACK} has not been build (BRATS have failed) 
EOF
cat << EOF > mail-output/body-failed.txt
${BUILDPACK} has not been build (BRATS have failed) 
See concourse for details.
EOF
fi
