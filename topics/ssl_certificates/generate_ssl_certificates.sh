#!/bin/bash

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CERT_OUT=${1:-${SCRIPT_PATH}/output}
echo "Output is generated in ${CERT_OUT}"

mkdir -p ${CERT_OUT}

# Generate the private key of the certificate authority
openssl genrsa -out ${CERT_OUT}/ca.key 4096

# Generate the certificate of the certificate authority (like a public key)
openssl req -new -x509 \
    -sha256 \
    -key ${CERT_OUT}/ca.key \
    -out ${CERT_OUT}/ca.crt \
    -days 7000 \
    -subj "/CN=SimonCA"

# Generate the private key of the server
openssl genrsa -out ${CERT_OUT}/server.key 4096

# Generate the certificate signing request (CSR) of the server to the CA
openssl req -new \
    -sha256 \
    -key ${CERT_OUT}/server.key \
    -out ${CERT_OUT}/server.csr \
    -subj "/CN=localhost" \
    -config ${SCRIPT_PATH}/ssl.conf

# Sign the signing request using the private key of the CA
openssl x509 -req \
    -in ${CERT_OUT}/server.csr \
    -CA ${CERT_OUT}/ca.crt \
    -CAkey ${CERT_OUT}/ca.key \
    -set_serial 01 \
    -out ${CERT_OUT}/server.crt \
    -days 7000 \
    -extensions req_ext \
    -extfile ${SCRIPT_PATH}/ssl.conf

# Generate the private key of the client
openssl genrsa -out ${CERT_OUT}/client.key 4096

# Generate the certificate signing request (CSR) of the client to the CA
openssl req -new \
    -sha256 \
    -key ${CERT_OUT}/client.key \
    -out ${CERT_OUT}/client.csr \
    -subj "/CN=localhost"

# Sign the signing request using the private key of the CA
openssl x509 -req \
    -in ${CERT_OUT}/client.csr \
    -CA ${CERT_OUT}/ca.crt \
    -CAkey ${CERT_OUT}/ca.key \
    -set_serial 01 \
    -out ${CERT_OUT}/client.crt \
    -days 7000
