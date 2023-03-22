#!/bin/bash
echo "this is pre build"
export HTTP_PROXY=$BUILD_PROXY
export HTTPS_PROXY=$BUILD_PROXY
echo "lets do a pip install"
pip install -r requirements.txt