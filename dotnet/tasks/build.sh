#!/bin/bash
set -e
set -x

DOTNET_VERSION="${DOTNET_VERSION:-2.2.100}"

# NOTE: https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L179

pushd git.dotnet-cli
	bash run-build.sh
popd

