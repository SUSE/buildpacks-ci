#!/bin/bash

set -e

source ci/brats/tasks/cf_login.sh

# make sure that we do not test the git version but the buildpack one

cd git.buildpack
# Make sure the manifest and version file from git are not used
rm manifest.yml VERSION

unzip ../s3.suse-buildpacks-staging/*.zip  manifest.yml VERSION

git commit manifest.yml VERSION -m "Replace manifest and VERSION by the version to test"

scripts/brats.sh

if [ $? -ne 0 ]; then
cat << EOF > ../mail-output/subject-failed.txt
[CI] ${BUILDPACK} BRATs have failed
EOF
cat << EOF > ../mail-output/body-failed.txt
The ${BUILDPACK} BRATs have failed for the following buildpack: $(cat ../s3.suse-buildbacks-staging/url)

See concourse for more details.
EOF
fi
