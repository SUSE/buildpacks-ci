#!/bin/bash

set -e -o pipefail

echo "[CI] ${BUILDPACK} ${TEST_SUITE} tests have failed" > mail-output/subject-failed.txt

source ci/brats/tasks/cf_login.sh 2>&1 | tee mail-output/body-failed.txt

# Setup git
git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

# make sure that we do not test the git version but the buildpack one
cd git.cf-buildpack
# Make sure the manifest and version file from git are not used
rm manifest.yml VERSION 2>&1 | tee ../mail-output/body-failed.txt

unzip ../s3.suse-buildpacks-staging/*.zip  manifest.yml VERSION 2>&1 | tee ../mail-output/body-failed.txt

git commit manifest.yml VERSION -m "Replace manifest and VERSION by the version to test" 2>&1 | tee ../mail-output/body-failed.txt

if [ "${TEST_SUITE}" == "brats" ]; then
  scripts/${TEST_SUITE}.sh 2>&1 | tee ../mail-output/body-failed.txt
else
  # Do not fail on integration tests at the moment
  scripts/${TEST_SUITE}.sh 2>&1 | tee ../mail-output/body-failed.txt
fi
