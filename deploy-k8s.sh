#!/usr/bin/env bash


if [ -d "./certs" ] ; then

export DEV_PORTAL_TLS_CERT=./certs/cert.pem
export DEV_PORTAL_TLS_CHAIN=./certs/fullchain.pem
export DEV_PORTAL_TLS_KEY=./certs/privkey.pem

kubectl create secret generic dev-portal-certs \
  --from-file=cert.pem="${DEV_PORTAL_TLS_CERT}" \
  --from-file=privkey.pem="${DEV_PORTAL_TLS_KEY}" \
  --from-file=fullchain.pem="${DEV_PORTAL_TLS_CHAIN}"

fi

cat deployment.yaml  | kubectl apply -f -
