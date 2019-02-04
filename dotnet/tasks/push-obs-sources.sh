#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

# Not present in the obs docker image
pip install awscli --upgrade --user

if [ -n "$DOTNET_VERSION" ];
then
  mkdir dotnet-deps
  ~/.local/bin/aws s3 cp s3://${STAGING_BUILDPACKS_BUCKET}/dependencies/dotnet/dotnet-cli-${DOTNET_VERSION}-src.tar.gz dotnet-deps
else
  # Get all the dotnet sources we have generated from s3 and update the obs packages
  ~/.local/bin/aws s3 cp s3://${STAGING_BUILDPACKS_BUCKET}/dependencies/dotnet dotnet-deps --recursive --exclude "*" --include "dotnet-cli-*.tar.gz"
fi

for file in dotnet-deps/*.tar.gz; do
    version=$(echo $file | sed -E 's/.*dotnet-cli-(.*)-src.*/\1/g')
    bash ${ROOTDIR}/ci/dotnet/tasks/make-obs-package.sh dotnet-cli $version $file
done