#!/bin/bash

set -e

source ci/brats/tasks/cf_login.sh

# Delete leftover apps
for app in $(cf apps | awk '{print $1}'); do cf delete -f $app; done

# Delete all buildpacks (in case there are leftovers)
for buildpack in $(cf buildpacks | tail -n +4 | awk '{print $1}'); do cf delete-buildpack -f $buildpack; done
