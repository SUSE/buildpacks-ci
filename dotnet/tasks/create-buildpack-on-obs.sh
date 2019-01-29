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
~/.local/bin/aws s3 cp s3://${STAGING_BUILDPACKS_BUCKET}/dependencies/dotnet dotnet-deps --recursive --exclude "dotnet-cli-*"


for i in $(seq 1 ${NUMBER_OF_RETRIES}); do
  echo "Buildpack ${BUILDPACK} could not be created" > ${ROOTDIR}/out/failure_email_notification_subject

  DEPDIR=${ROOTDIR}/dotnet-deps ${ROOTDIR}/cf-obs-binary-builder/bin/cf_obs_binary_builder \
        buildpack ${BUILDPACK} ${release_tag} ${revision} \
        2>&1 | tee ${ROOTDIR}/out/failure_email_notification_body

  exit_status=${PIPESTATUS[0]}

  echo "exit status: ${exit_status}"

  if [ ${exit_status} -eq 2 ]; then
    echo "Retrying in ${WAITING_TIME_SECS}..."
    sleep $WAITING_TIME_SECS
  elif [ ${exit_status} -eq 1 ]; then
    exit 1
  else
    exit 0
  fi
done

exit 1