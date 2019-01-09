#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

echo "Setting up oscrc"
sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

release_tag=$(cat $ROOTDIR/buildpack-gh-release/tag)
release_tag=${release_tag:1} # Strip the "v" from e.g. v1.7.22

# Revision is 1 because this task is triggered by new releases only.
# If a manually change something, we would be calling the tool manually with
# a different revision number.
revision=1

# Not present in the obs docker image
pip install awscli --upgrade --user

# Get all the dotnet deps we have generated so far, different buildpacks versions
# could consume different components
~/.local/bin/aws s3 cp s3://${STAGING_BUILDPACKS_BUCKET}/dependencies/dotnet dotnet-deps --recursive

echo "Buildpack ${BUILDPACK} could not be created" > $ROOTDIR/out/failure_email_notification_subject
DEPDIR=dotnet-deps $ROOTDIR/cf-obs-binary-builder/bin/cf_obs_binary_builder buildpack ${BUILDPACK} ${release_tag} ${revision} 2>&1 | tee $ROOTDIR/out/failure_email_notification_body
