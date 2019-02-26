#!/bin/bash

set -e -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

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

UPSTREAM_VERSION=$(cat gh-release.buildpack/version)

# make sure that we do not test the git version but the buildpack one
cd git.cf-buildpack

# Make sure we can check out our remote branch because concourse restricts to master
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git fetch origin
git checkout ${UPSTREAM_VERSION}

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
  # https://github.com/cloudfoundry/libbuildpack/pull/24/files
  if [ "$CF_STACK" == "sle12" ]; then
    export CF_STACK_DOCKER_IMAGE=$STAGING_DOCKER_REGISTRY/splatform/rootfs-$CF_STACK
  else
    export CF_STACK_DOCKER_IMAGE=registry.opensuse.org/cloud/platform/stack/rootfs/images/sle15:latest
  fi
  # Mount cgroups to be able to call docker in docker
  echo "Setup CGroups"
  source $SCRIPT_DIR/helpers.sh
  permit_device_control

  echo "Starting docker daemon"
  # Start docker daemon and wait until it's up
  dockerd &> /dev/null &
  sleep 10 # Give dockerd enough time to start
  docker version
  echo "Docker is up and running!"

  if [ "$CF_STACK" == "sle12" ]; then
    # Integration tests need access to the staging registry to fetch the sle12 stack
    docker login \
      -u $STAGING_DOCKER_REGISTRY_USERNAME \
      -p $STAGING_DOCKER_REGISTRY_PASSWORD $STAGING_DOCKER_REGISTRY
  fi

  # Do not fail on integration tests at the moment
  scripts/${TEST_SUITE}.sh 2>&1 | tee ../mail-output/body-failed.txt
fi
