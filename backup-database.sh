#!/usr/bin/env bash

docker exec -it graphql-dev-portal drush sql-dump --skip-tables-list='cache,cache_*,cache*,watchdog' > ./backup/db.sql