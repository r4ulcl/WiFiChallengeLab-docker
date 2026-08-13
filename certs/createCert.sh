#!/bin/bash

#https://wiki.innovaphone.com/index.php?title=Howto:802.1X_EAP-TLS_With_FreeRadius#Creation_Of_A_Self-Signed_CA_Certificate

# Global variable for certificate validity in days (10 years)
CERT_VALIDITY_DAYS=3650

# Clean up any existing files
rm -f ca.* client.* client_leak.* server.*

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

# RFC 5280-conformant CA: assert keyCertSign/cRLSign, mark critical. No legacy
# Netscape extensions and no dead CRL/policy URLs (CRL checking is not used).
cat <<EOF > ca.ext
extensions = x509v3

[ x509v3 ]
basicConstraints = critical,CA:true,pathlen:0
keyUsage         = critical,keyCertSign,cRLSign
EOF

openssl x509 -days $CERT_VALIDITY_DAYS -extfile ca.ext -signkey ca.key -in ca.csr -req -out ca.crt

# Creation Of A Server Certificate
openssl genrsa -out server.key 2048

# CN identifies the RADIUS server (not the CA). The same name is added to the
# SAN so server-name verification works if a supplicant ever enables it.
SERVER_NAME=radius.wifichallenge.com

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
stateOrProvinceName_default     = Madrid
localityName                    = "3. Locality Name            (eg, city)     "
localityName_default            = Madrid
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = WiFiChallenge
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Server
commonName                      = "6. Common Name              (eg, server FQDN)"
commonName_max                  = 64
commonName_default              = $SERVER_NAME
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = server@WiFiChallenge.com
EOF

# End-entity server cert: serverAuth only, keyUsage marked critical, explicit
# CA:FALSE. No legacy Netscape / Server-Gated-Crypto extensions.
cat <<EOF > server.ext
extensions = x509v3

[ x509v3 ]
basicConstraints = critical,CA:FALSE
keyUsage         = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[ alt_names ]
DNS.1 = $SERVER_NAME
EOF

# Add gateway IPs 192.168.1.1 .. 192.168.40.1 to the SAN. The lab uses subnets
# up to 192.168.30 (IP_OTHER0) plus 192.168.21 (IP_ROAM1 / PSK campus); the extra
# headroom means new networks won't trip a Firefox name-mismatch warning
# (SSL_ERROR_BAD_CERT_DOMAIN) on their captive/config portal.
COUNTER=1
for i in $(seq 1 40); do
    echo "IP.$COUNTER = 192.168.$i.1" >> server.ext
    ((COUNTER++))
done

# Initialize CA serial number
echo -ne '01' > ca.serial

# Create the Certificate Signing Request (CSR)
openssl req -config server.conf -new -key server.key -out server.csr

# Create the server certificate signed by the CA
openssl x509 -days $CERT_VALIDITY_DAYS -extfile server.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in server.csr -req -out server.crt

# Shared client extensions: end-entity EAP-TLS client cert (clientAuth EKU),
# explicit CA:FALSE, keyUsage marked critical, no legacy Netscape fields.
cat <<EOF > client.ext
extensions = x509v3

[ x509v3 ]
basicConstraints = critical,CA:FALSE
keyUsage         = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
EOF

# ---------------------------------------------------------------------------
# Secure client certificate (privacy-hardened)
# ---------------------------------------------------------------------------
# Subject contains ONLY the Common Name, set to the EAP identity
# (GLOBAL\GlobalAdmin). No email, organization, or location fields, so nothing
# beyond the username is exposed over the air during the EAP-TLS handshake.
# The CN matches the identity so the AP/RADIUS can bind this cert to one user.
# NOTE: the backslash in the CN default must be doubled for the OpenSSL parser.
openssl genrsa -out client.key 2048

cat <<EOF > client.conf
[ req ]
default_bits       = 2048
distinguished_name = req_DN
string_mask        = nombstr

[ req_DN ]
commonName                      = "6. Common Name              (eg, username)  "
commonName_max                  = 64
commonName_default              = GLOBAL\\\\GlobalAdmin
EOF

openssl req -config client.conf -new -key client.key -out client.csr
openssl x509 -days $CERT_VALIDITY_DAYS -extfile client.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in client.csr -req -out client.crt
cat client.crt client.key > client.pem.crt

# ---------------------------------------------------------------------------
# Leaky client certificate (for comparison / demonstration only)
# ---------------------------------------------------------------------------
# Belongs to a different user (GLOBAL\franz.ka) and stuffs the subject with PII
# (email, organization, department, location). In EAP-TLS the client cert is
# sent in cleartext during a TLS <=1.2 handshake, so all of these fields leak
# to any passive sniffer. Use this to contrast against the secure cert above.
openssl genrsa -out client_leak.key 2048

cat <<EOF > client_leak.conf
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
organizationalUnitName_default  = IT Department
commonName                      = "6. Common Name              (eg, username)  "
commonName_max                  = 64
commonName_default              = GLOBAL\\\\franz.ka
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = franz.ka@wifichallenge.com
EOF

openssl req -config client_leak.conf -new -key client_leak.key -out client_leak.csr
openssl x509 -days $CERT_VALIDITY_DAYS -extfile client.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in client_leak.csr -req -out client_leak.crt
cat client_leak.crt client_leak.key > client_leak.pem.crt
