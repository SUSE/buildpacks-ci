#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../
PACKAGE=$1
VERSION=$2
SOURCE_TARBALL=$3
ATOM="${PACKAGE}-${VERSION}"
echo "Pushing sources for ${ATOM}"

function setup_oscrc() {

    echo "Setting up oscrc"
    sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
    sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

}

function package_exists_in_obs() {

    local package=$1
    local prj=$2
    if osc search --package ${package} | grep -q $prj;
    then 
        return 0
    fi

    return 1

}

function checkout_package_in_obs() {

    local package=$1
    local prj=$2

    osc checkout ${prj}/${package} -o obs-${package}    
}

function create_package_in_obs() {

    local package=$1
    local prj=$2
cat << EOF > metadata
<package project="${prj}" name="${package}">
  <title>${package}</title>
  <description>
    Automatic source submit of ${package} for the use in buildpacks in SCF.
  </description>
</package>
EOF
    osc meta pkg $prj $package -F metadata
    rm -rf metadata
    checkout_package_in_obs $package $prj || true
}

function commit_package_in_obs() {

    local package=$1

    pushd obs-${package} 
        osc addremove
        osc commit -m "Commiting files"
    popd
}

function reset_package_in_obs() {

    local package=$1
    local prj=$2

    checkout_package_in_obs $package $prj || true

    pushd obs-${package} 
        rm -rfv *
    popd

    commit_package_in_obs $package
}

setup_oscrc

if package_exists_in_obs $ATOM $OBS_PROJECT;
then
 echo "$ATOM already exists in OBS, skipping."
 exit 0
 # TODO: Add a force flag
 # reset_package_in_obs $ATOM $OBS_PROJECT
else
 create_package_in_obs $ATOM $OBS_PROJECT
fi

cp -rfv $SOURCE_TARBALL obs-${ATOM}/
commit_package_in_obs $ATOM