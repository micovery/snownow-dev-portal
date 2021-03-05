#!/usr/bin/env bash

 docker run --rm -it \
            --publish 9090:80 \
            --publish 9093:443 \
            --name graphql-dev-portal \
            micovery/snownow-dev-portal:latest