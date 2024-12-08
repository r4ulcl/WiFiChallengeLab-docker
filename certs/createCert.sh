#!/bin/bash

#https://wiki.innovaphone.com/index.php?title=Howto:802.1X_EAP-TLS_With_FreeRadius#Creation_Of_A_Self-Signed_CA_Certificate

# Global variable for certificate validity in days (10 years)
CERT_VALIDITY_DAYS=3650

# Clean up any existing files
rm -f ca.* client.* server.*

# Creation Of A Self-Signed CA Certificate
openssl genrsa -out ca.key 2048

cat <<EOF > ca.conf
[ req ]
default_bits       = 2048
distinguished_name = req_DN
string_mask        = nombstr

[ req_DN ]
countryName                     = "1. Country Name             (2 letter code)"
countryName_default             = ES
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = "2. State or Province Name   (full name)    "
stateOrProvinceName_default     = Madrid
localityName                    = "3. Locality Name            (eg, city)     "
localityName_default            = Madrid
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = WiFiChallenge
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Certificate Authority
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallenge CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = ca@WiFiChallenge.com
EOF

openssl req -config ca.conf -new -key ca.key -out ca.csr

cat <<EOF > ca.ext
extensions = x509v3

[ x509v3 ]
basicConstraints      = CA:true,pathlen:0
crlDistributionPoints = URI:http://WiFiChallenge.com/ca/mustermann.crl
nsCertType            = sslCA,emailCA,objCA
nsCaPolicyUrl         = "http://WiFiChallenge.com/ca/policy.htm"
nsCaRevocationUrl     = "http://WiFiChallenge.com/ca/heimpold.crl"
nsComment             = "WiFiChallenge CA"
EOF

openssl x509 -days $CERT_VALIDITY_DAYS -extfile ca.ext -signkey ca.key -in ca.csr -req -out ca.crt

# Creation Of A Server Certificate
openssl genrsa -out server.key 2048

cat <<EOF > server.conf
[ req ]
default_bits       = 2048
distinguished_name = req_DN
string_mask        = nombstr

[ req_DN ]
countryName                     = "1. Country Name             (2 letter code)"
countryName_default             = ES
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = "2. State or Province Name   (full name)    "
localityName                    = "3. Locality Name            (eg, city)     "
localityName_default            = Madrid
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = WiFiChallenge
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Server
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallenge CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = server@WiFiChallenge.com
EOF

cat <<EOF > server.ext
extensions = x509v3

[ x509v3 ]
nsCertType       = server
keyUsage         = digitalSignature,nonRepudiation,keyEncipherment
extendedKeyUsage = msSGC,nsSGC,serverAuth
EOF

echo -ne '01' > ca.serial

openssl req -config server.conf -new -key server.key -out server.csr

openssl x509 -days $CERT_VALIDITY_DAYS -extfile server.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in server.csr -req -out server.crt

# Creation Of A Client Certificate
openssl genrsa -out client.key 2048

cat <<EOF > client.conf
[ req ]
default_bits       = 2048
distinguished_name = req_DN
string_mask        = nombstr

[ req_DN ]
countryName                     = "1. Country Name             (2 letter code)"
countryName_default             = ES
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = "2. State or Province Name   (full name)    "
stateOrProvinceName_default     = Madrid
localityName                    = "3. Locality Name            (eg, city)     "
localityName_default            = Madrid
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = WiFiChallenge
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallenge CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = client@WiFiChallenge.com
EOF

cat <<EOF > client.ext
extensions = x509v3

[ x509v3 ]
nsCertType = client,email,objsign
keyUsage   = digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment
EOF

openssl req -config client.conf -new -key client.key -out client.csr

openssl x509 -days $CERT_VALIDITY_DAYS -extfile client.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in client.csr -req -out client.crt

cat client.crt client.key > client.pem.crt
