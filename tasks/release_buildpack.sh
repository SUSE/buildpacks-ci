#!/bin/bash
set -e
# Setup osc
sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

# Setup git
git config --global user.email "$GIT_MAIL"
git config --global user.name "$GIT_USER"

FILENAME=$(wget https://download.opensuse.org/repositories/$PROJECT/buildpacks/ -qO - | egrep -o '[a-z]+_buildpack-v[0-9.]+-[a-z0-9]+.zip' | head -n1)
BUILDPACK_NAME=$(echo $FILENAME |sed -En 's/([a-z]+_buildpack)-v[0-9.]+-[a-z0-9]+.zip/\1/p')
BUILDPACK_VERSION=$(echo $FILENAME |sed -En 's/[a-z]+_buildpack-v([0-9.]+)-[a-z0-9]+.zip/\1/p')
pushd s3-output
wget https://download.opensuse.org/repositories/$PROJECT/buildpacks/$FILENAME

SHORT_CHECKSUM=$(echo $FILENAME | sed -En 's/.*-([0-9a-f]+).zip/\1/p')
DOWNLOAD_CHECKSUM=$(sha1sum $FILENAME | cut -d' ' -f1)
DOWNLOAD_SIZE=$(du -b $FILENAME)
if [[ ${DOWNLOAD_CHECKSUM:0:8} != $SHORT_CHECKSUM ]]; then
  echo "The file checksum did mismatch"
  exit 1
fi
popd

cp -a git.${BUILDPACK_NAME}-release/. git-output/
pushd git-output > /dev/null
cat << EOF > config/blobs.yml
---
${BUILDPACK_NAME}/${FILENAME}:
  size: ${DOWNLOAD_SIZE}
  object_id: ${FILENAME}
  sha: ${DOWNLOAD_CHECKSUM}
EOF
git commit config/blobs.yml -m "Bump to $FILENAME"
popd > /dev/null

echo $BUILDPACK_VERSION > git-tag/tag

osc release "$PROJECT" "$PACKAGE"

# generate email
cat << EOF > mail-output/subject.txt
${BUILDPACK_NAME} has been bumped to ${VERSION}
EOF

cat << EOF > mail-output/body.txt
${BUILDPACK_NAME} has been bumped to ${VERSION} (${FILENAME}).
See https://build.opensuse.org/project/show/Cloud:Platform:buildpacks/ for details.
EOF
