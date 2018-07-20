#!/bin/bash

set -e

source ci/tasks/cf_login.sh

# TODO: Change this to a generic name with resource mapping
ruby-buildpack/scripts/brats.sh
