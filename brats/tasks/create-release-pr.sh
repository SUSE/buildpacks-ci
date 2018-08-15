#!/bin/bash

set -ex

# Get rid of quotes in the beginning and end
export GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY:1:-1}

# Setup git
if [ -z "${GITHUB_TOKEN}"  ]; then
  echo "GITHUB_TOKEN environment variable not set"
  exit 1
fi

echo -e ${GITHUB_PRIVATE_KEY} > ~/.ssh/id_ecdsa
chmod 0600 ~/.ssh/id_ecdsa

git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

# Update the bosh release repo
pushd s3.suse-buildpacks
filename=$(ls *.zip)
filesize=$(du -b ${filename} | awk '{print $1}')
checksum=$(sha1sum ${filename} | cut -d' ' -f1)
popd

pushd git.buildpack-release
git checkout master
cat << EOF > config/blobs.yml
---
${BUILDPACK}-buildpack/${filename}:
  size: ${filesize}
  object_id: ${filename}
  sha: ${checksum}
EOF
commit_message="Bump to ${filename}"
git commit config/blobs.yml -m "${commit_message}"
git push origin

commit_id=`git rev-parse HEAD`
popd


# Open pull request
pushd git.scf
git_branch_name="incorporate_${filename}"
git checkout -b ${git_branch_name}

# Checkout buildpack submodule
pushd src/buildpacks/${BUILDPACK}-buildpack-release
git fetch
git checkout $commit_id
popd

# Create bump commit
git commit src/buildpacks/${BUILDPACK}-buildpack-release -m "Bump ${BUILDPACK} buildpack" -m "${commit_message}"
git push origin $git_branch_name

pr_message=`echo -e "Bump ${BUILDPACK} buildpack\n\n${commit_message}"`
export PR_URL=$(hub pull-request -m "${pr_message}")
popd
