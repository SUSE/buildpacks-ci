#!/bin/bash

set -e

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
RELEASE_TARBALL=$(ls *.zip)
SHA1SUM=$(sha1sum ${RELEASE_TARBALL} | cut -d' ' -f1)
SUSE_TAG=$(ls *.zip | grep -Eo 'v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)*')
SUSE_VERSION=$(echo ${SUSE_TAG} |  grep -Eo '[[:digit:]]+(\.[[:digit:]]+)+')
UPSTREAM_VERSION=$(echo ${SUSE_VERSION} | sed -E 's/^([[:digit:]]+(\.[[:digit:]]+)+)\.[[:digit:]]+$/\1/')
MESSAGE=$(cat <<MESSAGE
${SUSE_TAG}

[Upstream Release Notes for ${UPSTREAM_VERSION}](https://github.com/cloudfoundry/${BUILDPACK}-buildpack/releases/tag/v${UPSTREAM_VERSION})

[${RELEASE_TARBALL}](https://cf-buildpacks.suse.com/${RELEASE_TARBALL}) \`sha1:${SHA1SUM}\`
MESSAGE
)
popd

pushd git.cf-buildpack
  if [[ "${BUILDPACK}" != "java" ]]; then
    FILES="manifest.yml VERSION"
  else
    FILES="config/version.yml"
  fi
  unzip -o ../s3.cf-buildpacks.suse.com/*.zip  $FILES
  # Create commit if the SUSE related files are not up to date
  if ! git diff --no-ext-diff --quiet; then
    # Make sure we can check out our remote branch because concourse restricts to master
    git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git fetch origin

    git checkout ${UPSTREAM_VERSION}
    git commit $FILES -m "Add SUSE $FILES"
    git push origin ${UPSTREAM_VERSION}
    # Keep our master synced with the latest released version
    git push -f origin ${UPSTREAM_VERSION}:master

    # Create release
    hub release create -t ${UPSTREAM_VERSION} --message="${MESSAGE}" ${SUSE_TAG}
  fi
popd
