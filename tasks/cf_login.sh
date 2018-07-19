#!/bin/bash

cf login --skip-ssl-validation -a $CF_ENDPOINT -u $CF_USERNAME -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE
