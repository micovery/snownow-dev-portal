#!/usr/bin/env bash

export PORTAL_SERVICE_IMAGE=micovery/snownow-dev-portal:latest
docker build -t ${PORTAL_SERVICE_IMAGE}   .
