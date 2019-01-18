#!/bin/bash

set -e -o pipefail


zypper rm -y chromedriver
zypper in -y gconf2 liberation-fonts
wget -O chromedriver.zip 'https://chromedriver.storage.googleapis.com/2.34/chromedriver_linux64.zip'
[ e42a55f9e28c3b545ef7c7727a2b4218c37489b4282e88903e4470e92bc1d967 = "$(shasum -a 256 chromedriver.zip | cut -d' ' -f1)" ]
unzip chromedriver.zip -d /usr/local/bin/
rm chromedriver.zip

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

# In some cases the manifest stays intact after inflation and we don't want
# the script to exit because there is nothing to commit.
# (e.g. the binary buildpack comes from upstream)
if [[ -n $(git status -s | grep ' M') ]]; then
  git commit manifest.yml VERSION -m "Replace manifest and VERSION by the version to test" 2>&1 | tee ../mail-output/body-failed.txt
fi

if [ "${TEST_SUITE}" == "brats" ]; then
  scripts/${TEST_SUITE}.sh 2>&1 | tee ../mail-output/body-failed.txt
else
  # Do not fail on integration tests at the moment
  scripts/${TEST_SUITE}.sh 2>&1 | tee ../mail-output/body-failed.txt
fi
