#!/bin/bash

set -e

# Get rid of quotes in the beginning and end
export GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY:1:-1}

# Setup git
echo -e ${GITHUB_PRIVATE_KEY} > ~/.ssh/id_ecdsa
chmod 0600 ~/.ssh/id_ecdsa

git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

new_blobs_text="---"

for stack in $(echo $STACKS); do
  # Update the bosh release repo
  pushd s3.cf-buildpacks.suse.com.${stack}
  filename=$(ls *.zip)
  filesize=$(du -b ${filename} | awk '{print $1}')
  checksum=$(sha256sum ${filename} | cut -d' ' -f1)
  popd

  new_blobs_text+=$(cat <<'EOF'

${BUILDPACK}-buildpack/${filename}:
  size: ${filesize}
  object_id: ${filename}
  sha: sha256:${checksum}
EOF
)
done

pushd git.cf-buildpack-release
git checkout master
echo "$new_blobs_text" > config/blobs.yml

# bash generate random 32 character alphanumeric string (lowercase only)
# and write it in the ci_trigger file. Our CI monitors this file and generates
# a final release when it changes.
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > ci_trigger
git add config/blobs.yml ci_trigger

commit_message="Bump to ${filename}"
git commit -m "${commit_message}"
git push origin
popd
