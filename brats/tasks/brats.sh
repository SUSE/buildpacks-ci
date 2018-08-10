#!/bin/bash

set -e

source ci/brats/tasks/cf_login.sh

# make sure that we do not test the git version but the buildpack one
rm git.buildpack/manifest.yml git.buildpack/VERSION

cd git.buildpack
unzip s3.suse-buildbacks-staging-*/*.zip manifest.yml VERSION

scripts/brats.sh

if [ $? -ne 0 ]; then
cat << EOF > mail-output/subject-failed.txt
[CI] ${BUILDPACK} BRATs have failed
EOF
cat << EOF > mail-output/body-failed.txt
The ${BUILDPACK} BRATs have failed for the following buildpack: $(cat ../s3.suse-buildbacks-staging-*/url)

See concourse for more details.
EOF
fi
