#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

DOTNET_VERSION="${DOTNET_VERSION:-$(cat dotnet-core-buildpack-gh-release/body | grep 'Add dotnet-sdk' | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')}"
#DOTNET_VERSION="${DOTNET_VERSION:-2.2.100}"
STACK="${STACK:-sle12}"
BUILD="${BUILD:-true}"
DOTNET_BUNDLE_URL="${DOTNET_BUNDLE_URL:-https://dotnetcli.azureedge.net/dotnet/Sdk/$DOTNET_VERSION/dotnet-sdk-$DOTNET_VERSION-linux-x64.tar.gz}"
LOCAL_BUILD="${LOCAL_BUILD:-false}"
DOTNET_SHA="${DOTNET_SHA:-}"

OS="$(uname | tr '[:upper:]' '[:lower:]')"

export TERM="linux"
export DropSuffix="true"

function get_commit_sha() {
	# Get crystal to build depwatcher
	curl -H "Authorization: token ${OAUTH_AUTHORIZATION_TOKEN}" -s https://api.github.com/repos/crystal-lang/crystal/releases/latest | grep "browser_download_url.*linux-x86_64" | cut -d : -f 2,3 | tr -d '""' | wget -i - -O crystal-latest.tar.gz
	tar -xf crystal-latest.tar.gz
	rm -rf crystal-latest.tar.gz

	pushd crystal-*
		[ ! -e "/usr/local/bin/crystal" ] && ln -s $(pwd)/bin/crystal /usr/local/bin/crystal
		[ ! -e "/usr/local/bin/shards" ] && ln -s $(pwd)/bin/shards /usr/local/bin/shards
	popd

	echo "Compiling depwatcher"
	crystal build $ROOTDIR/depwatcher/dockerfiles/depwatcher/src/in.cr -o /usr/bin/depwatcher
	chmod +x /usr/bin/depwatcher

	# FIXME: Do we need version_filter? https://www.pivotaltracker.com/n/projects/1042066/stories/162580717
	DOTNET_SHA=$(echo '{"source":{"name":"dotnet-sdk","type":"dotnet-sdk", "tag_regex": "^(v1\\.\\d+\\.\\d+|v2\\.\\d+\\.\\d+\\+dependencies)$" }, "version":{"ref":"'$DOTNET_VERSION'", "url": "https://github.com/dotnet/cli"}}' | /usr/bin/depwatcher /tmp 2>&1 | grep 'sha' | jq -r '.git_commit_sha')
}

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

if [[ -z "${DOTNET_VERSION}" ]]; then
	echo "No DOTNET_VERSION specified"
	exit 1
fi

if [ "$BUILD" = true ]; then

	if [ "$LOCAL_BUILD" = true ] && [ ! -d "git.dotnet-cli" ]; then
		git clone https://github.com/dotnet/cli git.dotnet-cli
		pushd git.dotnet-cli
			echo "Trying to checkout Dotnet version: ${DOTNET_VERSION}"
			git checkout v${DOTNET_VERSION} || true
		popd
 	fi

	# dotnet/cli tags and sha returned by depwatcher are not the same
	# Retrieve sha from depwatcher if we can and if we didn't specified one manually
	if [[ -z "$DOTNET_SHA" ]]; then
		echo "Getting SHA for Dotnet version: ${DOTNET_VERSION}"
		get_commit_sha || true
	fi

	if [[ ! -z "$DOTNET_SHA" ]]; then
		echo "Checking out SHA $DOTNET_SHA"
		pushd git.dotnet-cli
			git checkout $DOTNET_SHA
		popd
	fi

	build
else
	TARBALL="$(basename $DOTNET_BUNDLE_URL)"
	[ ! -f "$TARBALL" ] && curl $DOTNET_BUNDLE_URL --output $TARBALL
	[ ! -d "cli-build" ] && mkdir cli-build
	tar xf $TARBALL -C cli-build
fi

# Extract dependencies from sdk and build separate dependencies
ruby ci/dotnet/tasks/extractor.rb ${STACK} ${DOTNET_VERSION} cli-build

[ ! -d "artifacts" ] && mkdir -p artifacts
mv *.tar.xz artifacts
