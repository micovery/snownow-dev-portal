#!/usr/bin/env bash

docker exec -it snownow-dev-portal drush sql-dump --skip-tables-list='cache,cache_*,cache*,watchdog' > ./backup/db.sql