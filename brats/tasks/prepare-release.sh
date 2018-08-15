#!/bin/bash
set -xe

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

# Get staging buildpack
file=`ls git.cf-buildpack-releases/*/*.json | tail -n1`
original_buildpack_url=`jq -r .url ${file}`
original_filename=$(basename ${original_buildpack_url})
wget $original_buildpack_url -O staging-buildpack.zip
unzip staging-buildpack.zip manifest.yml

shasum=`sha1sum staging-buildpack.zip`
checksum=${shasum:0:8}
if [[ ! $original_buildpack_url =~ ${checksum}\.zip ]]; then
  echo "Validation of downloaded buildpack checksum failed."
  exit 1
fi


# Copy artifacts
staging_urls=`ruby -ryaml -ruri <<EOF
manifest = YAML.load_file("manifest.yml")
dependencies = manifest["dependencies"].select do |d|
  d["uri"].include?("${STAGING_BUCKET_NAME}")
end.each do |d|
  url = URI.parse(d["uri"])
  puts "s3:/" + url.path
end
EOF
`

for url in ${staging_urls}; do
  echo aws s3 cp ${url} ${url/${STAGING_BUCKET_NAME}/${PRODUCTION_BUCKET_NAME}}
done


# Rewrite manifest
sed -i "s/${STAGING_BUCKET_NAME}/${PRODUCTION_BUCKET_NAME}/" manifest.yml


# Validate manifest
pushd git.upstream-buildpack
source .envrc
cp ../manifest.yml manifest.yml
(cd src/${BUILDPACK}/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager && go install)
if ! buildpack-packager build -cached=true -any-stack; then
  echo "buildpack-packager validation failed"
  exit 1
fi
popd


# Generate new buildpack
cp staging-buildpack.zip production-buildpack.zip
zip -r production-buildpack.zip manifest.yml

new_checksum=$(sha1sum production-buildpack.zip | cut -d' ' -f1)
new_filename=$(echo ${original_filename/-pre-/-} | sed -e "s/[0-9a-f]\{8\}.zip/${new_checksum:0:8}.zip/")
new_filesize=$(du -b production-buildpack.zip | awk '{print $1}')

mv production-buildpack.zip ${new_filename}


# Copy buildpack
aws s3 cp ${new_filename} s3://${PRODUCTION_BUCKET_NAME}/


# Update the bosh release repo
pushd git.buildpack-release
cat << EOF > config/blobs.yml
---
${BUILDPACK}-buildpack/${new_filename}:
  size: ${new_filesize}
  object_id: ${new_filename}
  sha: ${new_checksum}
EOF
git commit config/blobs.yml -m "Bump to ${new_filename}"
git push origin

commit_id=`git rev-parse HEAD`
commit_message=`git log --format=%b -n 1`
popd


# Open pull request
pushd git.scf
git_branch_name="incorporate_${new_filename}"
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
