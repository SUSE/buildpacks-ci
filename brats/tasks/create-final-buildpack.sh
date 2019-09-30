#!/bin/bash

set -xe

export BASE_DIR=$(pwd)

function update_urls_in_manifest {
  sed -i "s|https://s3.amazonaws.com/${STAGING_BUCKET_NAME}|${PRODUCTION_BUCKET_URL}|" manifest.yml
}

function extract_manifest_from {
  input=$1
  unzip "${BASE_DIR}/${input}/"*.zip  manifest.yml
}

function generate_new_buildpack {
  input=$1
  pushd $input

  extract_manifest_from $input
  update_urls_in_manifest

  original_filename=$(basename $(ls *.zip))
  cp ${original_filename} production-buildpack.zip
  zip -r production-buildpack.zip manifest.yml

  new_checksum=$(sha256sum production-buildpack.zip | cut -d' ' -f1)
  new_filename=$(echo ${original_filename/-pre-/-} | sed -e "s/[0-9a-f]\{8\}.zip/${new_checksum:0:8}.zip/")

  mv production-buildpack.zip ${BASE_DIR}/out.${input}/${new_filename}
  popd
}

extract_manifest_from s3.suse-buildpacks-staging

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

echo "Copying dependencies from staging to production bucket"
for url in ${staging_urls}; do
  echo ">> Copying ${url} to ${PRODUCTION_BUCKET_NAME}"
  aws s3 cp ${url} ${url/${STAGING_BUCKET_NAME}/${PRODUCTION_BUCKET_NAME}}
done

update_urls_in_manifest

# Validate manifest
pushd git.cf-buildpack
source .envrc
cp ../manifest.yml manifest.yml

if ! buildpack-packager build -cached=true -any-stack; then
  # Current binary buildpacks are also shipping with windows binaries
  # but they are not build in this test so it fails.
  # Our shipped buildpack does provide the Windows binaries though and
  # the binary buildpack does not have any external dependencies so a
  # verification is not needed.
  if [ "${BUILDPACK}" != "binary" ]; then
    echo "buildpack-packager validation failed"
    exit 1
  fi
fi
popd

# Update manifests in buildpacks
for bucket in s3.suse-buildpacks-staging*
do
  generate_new_buildpack $bucket
done
