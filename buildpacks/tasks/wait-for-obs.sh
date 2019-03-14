#!/bin/bash

set -e

echo "Setting up oscrc"
sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

release_tag=$(cat buildpack-gh-release/tag)
release_tag=${release_tag:1} # Strip the "v" from e.g. v1.7.22

# Revision is 1 because this task is triggered by new releases only.
# If a manually change something, we would be calling the tool manually with
# a different revision number.
revision=1

package_name=${BUILDPACK}-buildpack-${release_tag}.${revision}

echo "Wait for buildpack to build ..."
for i in $(seq 1 ${NUMBER_OF_RETRIES}); do
  OUTPUT=$(osc results ${OBS_BUILDPACK_PROJECT} ${package_name})
  if $(echo $OUTPUT | grep -q succeeded); then
    echo "Building ${package_name} in OBS succeded."
    exit 0
  elif $(echo $OUTPUT | grep -q failed); then
    echo "Building ${package_name}} in OBS failed."
    exit 1
  else
    echo "Retrying in ${WAITING_TIME_SECS}..."
    sleep $WAITING_TIME_SECS
  fi
done

echo "Timeout"
exit 1
