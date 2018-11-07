#!/bin/bash

set -e

# Get rid of quotes in the beginning and end
export GITHUB_PRIVATE_KEY=${GITHUB_PRIVATE_KEY:1:-1}

# Setup git
mkdir -p ~/.ssh/
echo -e ${GITHUB_PRIVATE_KEY} > ~/.ssh/id_ecdsa
echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts
chmod 0600 ~/.ssh/id_ecdsa

git config --global user.email "${GIT_MAIL}"
git config --global user.name "${GIT_USER}"

UPSTREAM_VERSION=$(cat buildpack-gh-release/version)

echo "Rebasing the ${BUILDPACK} buildpack against upstream ${UPSTREAM_VERSION} failed" > out/failure_email_notification_subject
echo "The error output is available in the according Concourse job." > out/failure_email_notification_body

pushd git.cf-buildpack
  # Make sure all tags are available
  git fetch origin

  # Extract current SUSE changes
  CURRENT_VERSION=$(cat VERSION |  grep -Eo '^[[:digit:]]+.[[:digit:]]+.[[:digit:]]+')
  git reset v${CURRENT_VERSION}

  # Reset SUSE VERSION and manifest.yml file to its original state
  git checkout VERSION
  git checkout manifest.yml

  # Create a commit for remaining SUSE changes
  if ! git diff --no-ext-diff --quiet; then
    git commit -a -m "Currently required SUSE changes"
  fi

  # Rebase against upstream
  git remote add upstream https://github.com/cloudfoundry/${BUILDPACK}-buildpack.git
  git fetch upstream --tags
  git rebase v${UPSTREAM_VERSION}

  git push origin master || git push -f origin master
  # Make sure that our fork has the same tags as upstream
  git push origin --tags

  # Fork
  git checkout -b ${UPSTREAM_VERSION}
  git push origin ${UPSTREAM_VERSION}
popd