#!/bin/bash

set -e

# Make JAVA_HOME available for tetra
. /etc/profile

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

echo "Setting up oscrc"
sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

echo "Setting up local git"
# This is needed for bundling the jruby sources using tetra. Tetra uses local git repositories for
# tracking downloaded dependencies
git config --global user.name "John Doe"
git config --global user.email johndoe@example.com

echo "Compiling depwatcher"
crystal build $ROOTDIR/depwatcher/dockerfiles/depwatcher/src/in.cr -o /usr/bin/depwatcher
chmod +x /usr/bin/depwatcher

release_tag=$(cat $ROOTDIR/buildpack-gh-release/tag)
manifest_url="https://raw.githubusercontent.com/cloudfoundry/${BUILDPACK}-buildpack/${release_tag}/manifest.yml"
echo "Downloading manifest: ${manifest_url}"
wget $manifest_url

echo "Buildpack dependencies for ${BUILDPACK} buildpack ${release_tag} could not be built" > $ROOTDIR/out/failure_email_notification_subject
$ROOTDIR/cf-obs-binary-builder/bin/cf_obs_binary_builder sync manifest.yml 2>&1 | tee $ROOTDIR/out/failure_email_notification_body

exit ${PIPESTATUS[0]}
