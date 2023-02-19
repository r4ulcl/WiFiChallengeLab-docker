#https://wiki.innovaphone.com/index.php?title=Howto:802.1X_EAP-TLS_With_FreeRadius#Creation_Of_A_Self-Signed_CA_Certificate
# 2048 

#Clean
rm ca.* client.* server.*

#Creation Of A Self-Signed CA Certificate
openssl genrsa -out ca.key 2048

echo '[ req ]
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
0.organizationName_default      = WiFiChallengeLab
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Certificate Authority
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallengeLab CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = ca@WiFiChallengeLab.com' > ca.conf

openssl req -config ca.conf -new -key ca.key -out ca.csr

echo '
extensions = x509v3
 
[ x509v3 ]
basicConstraints      = CA:true,pathlen:0
crlDistributionPoints = URI:http://WiFiChallengeLab.com/ca/mustermann.crl
nsCertType            = sslCA,emailCA,objCA
nsCaPolicyUrl         = "http://WiFiChallengeLab.com/ca/policy.htm"
nsCaRevocationUrl     = "http://WiFiChallengeLab.com/ca/heimpold.crl"
nsComment             = "WiFiChallengeLab CA"
' > ca.ext

openssl x509 -days 1095 -extfile ca.ext -signkey ca.key -in ca.csr -req -out ca.crt

#Creation Of A Server Certificate
openssl genrsa -out server.key 2048
echo '
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
#stateOrProvinceName_default     = 
localityName                    = "3. Locality Name            (eg, city)     "
localityName_default            = Madrid
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = WiFiChallengeLab
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Server
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallengeLab CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = server@WiFiChallengeLab.com

' > server.conf 

echo 'extensions = x509v3
 
[ x509v3 ]
nsCertType       = server
keyUsage         = digitalSignature,nonRepudiation,keyEncipherment
extendedKeyUsage = msSGC,nsSGC,serverAuth' > server.ext

echo -ne '01' > ca.serial

openssl req -config server.conf -new -key server.key -out server.csr

openssl x509 -days 730 -extfile server.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in server.csr -req -out server.crt

#Creation Of A Client Certificate
openssl genrsa -out client.key 2048

echo '[ req ]
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
0.organizationName_default      = WiFiChallengeLab
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
#organizationalUnitName_default  = 
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = WiFiChallengeLab CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = client@WiFiChallengeLab.com' > client.conf

echo 'extensions = x509v3
 
[ x509v3 ]
nsCertType = client,email,objsign
keyUsage   = digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment' > client.ext

openssl req -config client.conf -new -key client.key -out client.csr
openssl x509 -days 730 -extfile client.ext -CA ca.crt -CAkey ca.key -CAserial ca.serial -in client.csr -req -out client.crt
cat client.crt client.key > client.pem.crt
