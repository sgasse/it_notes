# SSL Certificates

SSL certificates can be used to communicate in a secure and encrypted way with
services such as self-hosted RabbitMQ clusters or gRPC hosts.

## Idea

Server and client both get a private/public key pair. The public keys are turned
into certificates by signing them with the private key of a self-generated
certificate authority (CA). We add the certificate (related to the public key)
of the certificate authority to both the server and client chain. As long as
they trust the certificate authority, they can trust each other's certificates
signed with it.

## Setup

We describe the steps in bash commands. To create the output to a specific
folder when running as script, we can add this in the beginning:

```bash
#!/bin/bash

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CERT_OUT=${1:-${SCRIPT_PATH}/output}
echo "Output is generated in ${CERT_OUT}"
```

### Generate certificate authority

```bash
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
```

### Generate server key/certificate

For clients to trust the server, it is important that the DNS name of the server
shows up in `alt_names` in the configuration below. We create the configuration
as `ssl.conf` next to out script.

We can inspect if our certificate has the right alternative names by running:

```bash
openssl x509 -text -noout -in server.crt
```

```conf
[ req ]
default_bits       = 4096
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
countryName              = DE
stateOrProvinceName      = Bavaria
localityName_default     = Munich
organizationName_default = SimonCA
commonName               = localhost
commonName_max           = 64

[ req_ext ]
subjectAltName = @alt_names

# Add all names of servers for which the certificate should be used.
# gRPC accesspts `localhost` connections as long as the `commonName` is
# `localhost`, but RabbitMQ needs `localhost` also explicitly as DNS entry.
[ alt_names ]
DNS.1 = my.domain.de
DNS.2 = localhost
DNS.3 = 127.0.0.1
```

```bash
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
```

### Generate client key/certificate

Generating the key/certificate pair for the client is straight-forward since it
does not need any alternative names.

```bash
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
```
