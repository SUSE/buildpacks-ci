#!/bin/bash

set -e

source ci/brats/tasks/cf_login.sh

# Delete leftover apps
for app in $(cf apps | grep "cutlass-" | awk '{print $1}'); do cf delete -f $app; done

# Delete leftover buildpacks
for buildpack in $(cf buildpacks | grep "brats_" | awk '{print $1}'); do cf delete-buildpack -f $buildpack; done
