#!/bin/bash

set -e

BASE_DIR=$(pwd)

function extract_file_name_and_checksum_from {
  input=$1
  pushd ${BASE_DIR}/${input} > /dev/null
  release_tarball=$(ls *.zip)
  sha256sum=$(sha256sum ${release_tarball} | cut -d' ' -f1)
  popd > /dev/null
  echo -e "[${release_tarball}](https://cf-buildpacks.suse.com/${release_tarball})\n\`sha256:${sha256sum}\`"
}

if [ -z "${GITHUB_TOKEN}"  ]; then
  echo "GITHUB_TOKEN environment variable not set"
  exit 1
fi

# Get rid of quotes in the beginning and end
export GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY:1:-1}

# Setup git
mkdir -p ~/.ssh/
echo -e ${GITHUB_PRIVATE_KEY} > ~/.ssh/id_ecdsa
echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts
chmod 0600 ~/.ssh/id_ecdsa

git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

pushd s3.cf-buildpacks.suse.com
release_tarball=$(ls *.zip)
suse_tag=$(ls *.zip | grep -Eo 'v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)*')
suse_version=$(echo ${suse_tag} |  grep -Eo '[[:digit:]]+(\.[[:digit:]]+)+')
upstream_version=$(echo ${suse_version} | sed -E 's/^([[:digit:]]+(\.[[:digit:]]+)+)\.[[:digit:]]+$/\1/')
# Java buildpacks usually use a major and minor version only, while sometimes also shipping
# patch releases. To prevent conflicts with our own tags we add a "0.1" to all Java
# buildpack versions which only have a major and minor version.
# In this case we need to filter the patch level from the upstream_version too
if [[ "${BUILDPACK}" == "java" && "${suse_version}" =~ [0-9]+\.[0-9]+\.0\.1 ]]; then
  upstream_version=$(echo ${suse_version} | sed -E 's/^([[:digit:]]+(\.[[:digit:]]+)+)\.0\.1$/\1/')
fi
popd

releases=""
# Iterate over associated buildpacks (ignore the non-associated one)
for bucket in s3.cf-buildpacks.suse.com-*
do
  releases="${releases}\n\n$(extract_file_name_and_checksum_from $bucket)"
done

message=$(cat <<MESSAGE
${suse_tag}

[Upstream Release Notes for ${upstream_version}](https://github.com/cloudfoundry/${BUILDPACK}-buildpack/releases/tag/v${upstream_version})

$(echo -e $releases)
MESSAGE
)

pushd git.cf-buildpack
  if [[ "${BUILDPACK}" != "java" ]]; then
    files="manifest.yml VERSION"
  else
    files="config/version.yml"
  fi
  git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git fetch origin

  git checkout ${upstream_version}

  unzip -o ${BASE_DIR}/s3.cf-buildpacks.suse.com/*.zip  $files
  # Create commit if the SUSE related files are not up to date
  if ! git diff --no-ext-diff --quiet; then
    # Make sure we can check out our remote branch because concourse restricts to master
    git commit $files -m "Add SUSE $files"
    git push origin ${upstream_version}
    # Keep our master synced with the latest released version
    git push -f origin ${upstream_version}:master

    # Create release
    hub release create -t ${upstream_version} --message="${message}" ${suse_tag}
  fi
popd
