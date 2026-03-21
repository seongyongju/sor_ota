#!/bin/bash

set -euo pipefail

SERVER_DIR=ota-ce-gen
DEVICES_DIR=ota-ce-gen/devices
CWD=$(dirname $0)
SERVER_NAME=ota.ce

HOSTS=(
  "127.0.0.1         reposerver.ota.ce"
  "127.0.0.1         keyserver.ota.ce"
  "127.0.0.1         director.ota.ce"
  "127.0.0.1         treehub.ota.ce"
  "127.0.0.1         deviceregistry.ota.ce"
  "127.0.0.1         campaigner.ota.ce"
  "127.0.0.1         app.ota.ce"
  "127.0.0.1         ota.ce"
)

for entry in "${HOSTS[@]}"; do
  host=$(echo "$entry" | awk '{print $2}')
  if ! grep -qF "$host" /etc/hosts; then
    echo "$entry" | sudo tee -a /etc/hosts > /dev/null
    echo "Added to /etc/hosts: $entry"
  fi
done

if [ -d "$SERVER_DIR" ] || [ -d "$DEVICES_DIR" ] ; then
    echo "${SERVER_DIR} or ${DEVICES_DIR} exists, aborting"
    exit 1
fi

mkdir -p "${SERVER_DIR}" "${DEVICES_DIR}"

openssl ecparam -genkey -name prime256v1 | openssl ec -out "${SERVER_DIR}/ca.key"

openssl req -new -x509 -days 3650 -config "${CWD}/certs/server_ca.cnf" \
        -key "${SERVER_DIR}/ca.key" \
        -out "${SERVER_DIR}/server_ca.pem"

openssl ecparam -genkey -name prime256v1 |
    openssl ec -out "${SERVER_DIR}/server.key"

openssl req -new -key "${SERVER_DIR}/server.key" \
        -config <(sed "s/\$ENV::SERVER_NAME/${SERVER_NAME}/g" "${CWD}/certs/server.cnf") \
    -out "${SERVER_DIR}/server.csr"

openssl x509 -req -days 3650 -in "${SERVER_DIR}/server.csr" -CAcreateserial \
        -extfile <(sed "s/\$ENV::SERVER_NAME/${SERVER_NAME}/g" "${CWD}/certs/server.ext") \
        -CAkey "${SERVER_DIR}/ca.key" -CA "${SERVER_DIR}/server_ca.pem" -out "${SERVER_DIR}/server.crt"

cat "${SERVER_DIR}/server.crt" "${SERVER_DIR}/server_ca.pem" > "${SERVER_DIR}/server.chain.pem"

openssl ecparam -genkey -name prime256v1 | openssl ec -out "${DEVICES_DIR}/ca.key"

openssl req -new -x509 -days 3650 -key "${DEVICES_DIR}/ca.key" -config "${CWD}/certs/device_ca.cnf" \
    -out "${DEVICES_DIR}/ca.crt"

