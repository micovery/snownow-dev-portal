#!/usr/bin/env bash

docker exec -it snownow-dev-portal bash -c '
cd ~ &&
rm -rf config &&
mkdir config &&
drush config-export --destination=~/config &&
tar -czvf config.tar.gz config/*
'
rm -rf ./backup/config.tar.gz
docker cp snownow-dev-portal:/drupal/config.tar.gz ./backup/config.tar.gz

pushd ./backup
tar -xzvf config.tar.gz
rm -rf config.tar.gz
popd