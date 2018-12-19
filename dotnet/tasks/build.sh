#!/bin/bash
set -e
set -x

DOTNET_VERSION="${DOTNET_VERSION:-2.1.302}"
STACK="${STACK:-sle12}"

OS="$(uname | tr '[:upper:]' '[:lower:]')"

# NOTE: https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L179

pushd git.dotnet-cli
	# NOTE: https://github.com/dotnet/cli/issues/8358
	
	# TODO: Apply patch if dotnet version in range https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L178
	sed -i 's/WriteDynamicPropsToStaticPropsFiles "\${args\[\@\]}"/WriteDynamicPropsToStaticPropsFiles/' run-build.sh || true
	bash build.sh /t:Compile

	#bash run-build.sh

	# TODO: Not tested yet
	# since >= v2.1.300
	[ -d "artifacts/${OS}-x64/stage2" ] && mv artifacts/${OS}-x64/stage2 ../cli-build
	# < v2.1.300
	[ -d "bin/2/${OS}-x64/dotnet" ] && mv bin/2/${OS}-x64/dotnet ../cli-build
popd

ruby ci/dotnet/tasks/extractor.rb ${STACK} ${DOTNET_VERSION} cli-build

mv *.tar.xz artifacts


# NOTE: Upstream dependency extraction, https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L194
