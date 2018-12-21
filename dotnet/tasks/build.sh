#!/bin/bash
set -e
set -x

DOTNET_VERSION="${DOTNET_VERSION:-2.1.302}"
STACK="${STACK:-sle12}"
BUILD="${BUILD:-true}"
DOTNET_BUNDLE_URL="${DOTNET_BUNDLE_URL:-https://dotnetcli.azureedge.net/dotnet/Sdk/$DOTNET_VERSION/dotnet-sdk-$DOTNET_VERSION-linux-x64.tar.gz}"
LOCAL_BUILD="${LOCAL_BUILD:-false}"

OS="$(uname | tr '[:upper:]' '[:lower:]')"

export TERM="linux"
export DropSuffix="true"

function build() {
	echo "Building dotnet $DOTNET_VERSION for $STACK stack"
	pushd git.dotnet-cli

		# See https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L177
		regex_extract_version="([0-9]+)\.([0-9]+)\.([0-9]+)"
		if [[ $DOTNET_VERSION =~ $regex_extract_version ]]
		then
			MAJOR="${BASH_REMATCH[1]}"
			MINOR="${BASH_REMATCH[2]}"
			PATCH="${BASH_REMATCH[3]}"
			echo "Major :$MAJOR"
			echo "Minor: $MINOR"
			echo "PATCH ver: $PATCH"

			if [[ "$MAJOR" -eq "2" ]] && \
			   [[ "$MINOR" -eq "1" ]] && \
			   [[ "$PATCH" -ge "4" ]] && \
			   [[ "$PATCH" -lt "300" ]]
			then
				sed -i 's/WriteDynamicPropsToStaticPropsFiles "\${args\[\@\]}"/WriteDynamicPropsToStaticPropsFiles/' run-build.sh
			fi

			if [[ "$MAJOR" -eq "2" ]] && \
			   [[ "$MINOR" -eq "0" ]] && \
			   [[ "$PATCH" -eq "3" ]]
			then
				sed -i 's/sles/opensuse/' /etc/os-release
				sed -i 's/12.3/42.1/' /etc/os-release
			fi

			if [[ "$MAJOR" -eq "2" ]] && \
			   [[ "$MINOR" -eq "1" ]] && \
			   [[ "$PATCH" -eq "401" ]]
			then
				# Handles: https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L164
				git cherry-pick 257cf7a4784cc925742ef4e2706e752ab1f578b0
			fi

		else
			echo "Could not extract version, skipping patch"
		fi

		bash build.sh /t:Compile

		# NOTE: To run a full build, including of self-tests: bash run-build.sh

		# Handles: https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L190
		[ -d "artifacts/${OS}-x64/stage2" ] && mv artifacts/${OS}-x64/stage2 ../cli-build
		[ -d "bin/2/${OS}-x64/dotnet" ] && mv bin/2/${OS}-x64/dotnet ../cli-build
	popd
}

if [ "$BUILD" = true ]; then
	build
else
	TARBALL="$(basename $DOTNET_BUNDLE_URL)"
	[ ! -f "$TARBALL" ] && curl $DOTNET_BUNDLE_URL --output $TARBALL
	[ ! -d "cli-build" ] && mkdir cli-build
	tar xf $TARBALL -C cli-build
fi

# Extract dependencies from sdk and build separate dependencies
if [ "$LOCAL_BUILD" = true ]; then
	ruby extractor.rb ${STACK} ${DOTNET_VERSION} cli-build
else
	ruby ci/dotnet/tasks/extractor.rb ${STACK} ${DOTNET_VERSION} cli-build
fi

[ ! -d "artifacts" ] && mkdir -p artifacts
mv *.tar.xz artifacts
