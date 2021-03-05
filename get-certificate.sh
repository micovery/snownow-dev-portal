#!/usr/bin/env bash

export EMAIL="$1"
if [ -z "$EMAIL" ] ; then
  echo "ERROR: email address is required"
  exit 1
fi

export DOMAIN="$2"
if [ -z "$DOMAIN" ] ; then
  echo "ERROR: domain is required"
  exit 1
fi

sudo certbot certonly   \
  --manual   \
  --preferred-challenges dns-01   \
  --agree-tos   \
  --manual-public-ip-logging-ok   \
  --email "${EMAIL}"   \
  -d "${DOMAIN}"