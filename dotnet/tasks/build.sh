#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../
STACK="${STACK:-sle15}"
BUILD="${BUILD:-true}"
DOTNET_BUNDLE_URL="${DOTNET_BUNDLE_URL:-https://dotnetcli.azureedge.net/dotnet/Sdk/$DOTNET_VERSION/dotnet-sdk-$DOTNET_VERSION-linux-x64.tar.gz}"
LOCAL_BUILD="${LOCAL_BUILD:-false}"
DOTNET_SHA="${DOTNET_SHA:-}"

if [[ -z "$DOTNET_VERSION" ]]; then
	release_tag=$(cat $ROOTDIR/dotnet-core-buildpack-gh-release/tag)
	DOTNET_VERSION="$($ROOTDIR/ci/dotnet/tasks/compare_manifests ${release_tag} | uniq)"
	[[ -z "$DOTNET_VERSION" ]] && DOTNET_VERSION="$(cat dotnet-core-buildpack-gh-release/body | grep 'Add dotnet-sdk' | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')"
fi

OS="$(uname | tr '[:upper:]' '[:lower:]')"

export TERM="linux"
export DropSuffix="true"

if [ "$STACK" == "sle15" ]; then
	zypper ar 'http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/SUSE:SLE-15:GA.repo'
	zypper --gpg-auto-import-keys -n in awk libevent-devel aws-cli zlib-devel libcurl-devel lttng-tools
fi

function get_commit_sha() {
	local version=$1
	# Get crystal to build depwatcher
	curl -H "Authorization: token ${OAUTH_AUTHORIZATION_TOKEN}" -s https://api.github.com/repos/crystal-lang/crystal/releases/latest | grep "browser_download_url.*linux-x86_64" | cut -d : -f 2,3 | tr -d '""' | wget -q -i - -O crystal-latest.tar.gz
	tar -xf crystal-latest.tar.gz
	rm -rf crystal-latest.tar.gz

	[ ! -e "/usr/local/bin/crystal" ] && ln -s $(pwd)/crystal-*/bin/crystal /usr/local/bin/crystal
	[ ! -e "/usr/local/bin/shards" ] && ln -s $(pwd)/crystal-*/bin/shards /usr/local/bin/shards

	crystal build $ROOTDIR/depwatcher/dockerfiles/depwatcher/src/in.cr -o /usr/bin/depwatcher
	chmod +x /usr/bin/depwatcher

	# FIXME: Do we need version_filter? https://www.pivotaltracker.com/n/projects/1042066/stories/162580717
	echo $(echo '{"source":{"name":"dotnet-sdk","type":"dotnet-sdk", "tag_regex": "^(v1\\.\\d+\\.\\d+|v2\\.\\d+\\.\\d+\\+dependencies)$" }, "version":{"ref":"'$version'", "url": "https://github.com/dotnet/cli"}}' | /usr/bin/depwatcher /tmp 2>&1 | grep 'sha' | jq -r '.git_commit_sha')
}

function build() {
	local version=$1
	local sha=$2
	local out=$3

	if [ "$LOCAL_BUILD" = true ]; then
		[ ! -d "git.dotnet-cli" ] && git clone https://github.com/dotnet/cli git.dotnet-cli
		pushd git.dotnet-cli
			echo "Trying to checkout Dotnet version: ${version}"
			git checkout v${version} || true
		popd
	fi

	# dotnet/cli tags and sha returned by depwatcher are not the same
	# Retrieve sha from depwatcher if we can and if we didn't specified one manually
	if [[ -z "$sha" ]]; then
		echo "Getting SHA for Dotnet version: ${version}"
		sha=$(get_commit_sha ${version}) || true
	fi

	if [[ ! -z "$sha" ]]; then
		echo "Checking out SHA (from depwatcher) $sha"
		pushd git.dotnet-cli
			git checkout $sha
		popd
	fi

	echo "Building dotnet $version for $STACK stack in $out"
	pushd git.dotnet-cli

		# See https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L177
		regex_extract_version="([0-9]+)\.([0-9]+)\.([0-9]+)"
		if [[ $version =~ $regex_extract_version ]]
		then
			MAJOR="${BASH_REMATCH[1]}"
			MINOR="${BASH_REMATCH[2]}"
			PATCH="${BASH_REMATCH[3]}"
			echo "Major: $MAJOR"
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

		if [[ "$MAJOR" -eq "2" ]]; then
			bash build.sh /t:Compile
		else
			bash build.sh
		fi

		# NOTE: To run a full build, including of self-tests: bash run-build.sh

		# Handles: https://github.com/cloudfoundry/buildpacks-ci/blob/2506ca13addb599c4fda9aaa68d5ba8586e3f40d/tasks/build-binary-new/builder.rb#L190
		[ -d "artifacts/${OS}-x64/stage2" ] && mv artifacts/${OS}-x64/stage2 ${out}
		[ -d "bin/2/${OS}-x64/dotnet" ] && mv bin/2/${OS}-x64/dotnet ${out}
	popd
}

if [[ -z "${DOTNET_VERSION}" ]]; then
	echo "No DOTNET_VERSION specified or to build"
	exit 0
fi

if [ "$BUILD" = true ]; then
	for i in ${DOTNET_VERSION}
	do
    if [[ $i =~ .*-preview.* ]]; then
      echo "Skip preview version ${i}"
      continue
    fi

		echo "Building dotnet version: ${i}"
		build "${i}" "${DOTNET_SHA}" "${ROOTDIR}/${i}-build"
		# Extract dependencies from sdk and build separate dependencies
		ruby ${ROOTDIR}/ci/dotnet/tasks/extractor.rb ${STACK} ${i} "${ROOTDIR}/${i}-build"

		[ ! -d "${ROOTDIR}/artifacts" ] && mkdir -p "${ROOTDIR}"/artifacts
		mv *.tar.xz "${ROOTDIR}"/artifacts

		mkdir -p "${ROOTDIR}"/"${i}"-src/tmp
		mkdir -p "${ROOTDIR}"/"${i}"-src/cache
		
		mv "${ROOTDIR}/git.dotnet-cli" "${ROOTDIR}"/"${i}"-src/source

		# Get temp files 
		for s in "/tmp/.*.cs" "/tmp/VBCSCompiler";
		do
			# Best effort, as aren't necessary files left there.
			mv "${s}" "${ROOTDIR}"/"${i}"-src/tmp/ || true
		done

		for s in "${ROOTDIR}/${i}-src/source/.dotnet_stage0" "$HOME/.dotnet" "$HOME/.nuget" "$HOME/.local/share/NuGet";
		do
			mv "${s}" "${ROOTDIR}"/"${i}"-src/cache/
		done

		# Strip dlls and exes from the sources
		find "${ROOTDIR}"/"${i}"-src/ -regextype posix-egrep -regex ".*\.(dll|exe)$" -type f -delete

		tar -czvf ${ROOTDIR}/artifacts/dotnet-cli-"${i}"-src.tar.gz "${ROOTDIR}"/"${i}"-src/
	done
	ls -liah artifacts/
else

	TARBALL="$(basename $DOTNET_BUNDLE_URL)"
	[ ! -f "$TARBALL" ] && curl $DOTNET_BUNDLE_URL --output $TARBALL
	[ ! -d "cli-build" ] && mkdir cli-build
	tar xf $TARBALL -C cli-build
	# Extract dependencies from sdk and build separate dependencies
	ruby ci/dotnet/tasks/extractor.rb ${STACK} ${DOTNET_VERSION} cli-build

	[ ! -d "artifacts" ] && mkdir -p artifacts
	mv *.tar.xz artifacts

fi

pushd ${ROOTDIR}/artifacts
for a in $(ls); do
	aws s3 cp "${a}" s3://${STAGING_BUILDPACKS_BUCKET}/dependencies/dotnet/${a}
done
