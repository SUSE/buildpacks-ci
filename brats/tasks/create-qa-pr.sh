#!/bin/bash

export FILENAME=$(basename $(ls s3.suse-buildpacks-staging/*.zip))
export GIT_BRANCH_NAME="trigger_${FILENAME}_release"
# Get rid of quotes in the beginning and end
export GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY:1:-1}
export COMMIT_MESSAGE="Trigger release of $FILENAME"

if [ -z "${GITHUB_TOKEN}"  ]; then
  echo "GITHUB_TOKEN environment variable not set"
  exit 1
fi


# Setup git
echo -e ${GITHUB_PRIVATE_KEY} > ~/.ssh/id_ecdsa
chmod 0600 ~/.ssh/id_ecdsa

git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

# Create release commit
cd git.cf-buildpack-releases
git checkout -b $GIT_BRANCH_NAME

mkdir -p ${BUILDPACK}
cd ${BUILDPACK}

cat <<EOF > ${FILENAME}.json
{
  "url": "$(cat ../../s3.suse-buildpacks-staging/url)"
}
EOF

git add ${FILENAME}.json
git commit -m "${COMMIT_MESSAGE}"
git push origin ${GIT_BRANCH_NAME}

# Open a Pull Request
export PR_URL=$(hub pull-request -m "${COMMIT_MESSAGE}")

# Todo Mail
exit $?
