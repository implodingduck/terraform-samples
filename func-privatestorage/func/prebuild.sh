#!/bin/bash
echo "this is pre build"
export HTTP_PROXY=$APPSETTING_BUILD_PROXY
export HTTPS_PROXY=$APPSETTING_BUILD_PROXY
echo $HTTP_PROXY
echo $HTTPS_PROXY
echo "pre build done..."