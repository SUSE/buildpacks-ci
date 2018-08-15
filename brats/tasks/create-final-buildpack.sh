#!/bin/bash

set -xe

# Get staging buildpack
file=`ls git.cf-buildpack-releases/${BUILDPACK}/*.json | tail -n1`
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
  aws s3 cp ${url} ${url/${STAGING_BUCKET_NAME}/${PRODUCTION_BUCKET_NAME}}
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

mv production-buildpack.zip s3-out/${new_filename}
