#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

release_tag=$(cat $ROOTDIR/buildpack-gh-release/tag)
release_tag=${release_tag:1} # Strip the "v" from e.g. v1.7.22

# Revision is 1 because this task is triggered by new releases only.
# If a manually change something, we would be calling the tool manually with
# a different revision number.
revision=1

version="${release_tag}.${revision}"

pushd git.cf-buildpack
git checkout
echo "---" > config/version.yml
echo "version: v${version}" >> config/version.yml
bundle install
bundle exec rake clobber package
CHECKSUM=$(sha1sum build/java-buildpack-v${version}.zip | cut -d' ' -f1)
mv build/java-buildpack-v${version}.zip ../out/java-buildpack-v${version}-${CHECKSUM:0:8}.zip
popd
