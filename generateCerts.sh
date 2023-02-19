#!/bin/bash

rm -r APs/config/certs
rm -r Clients/config/certs

cd certs
bash createCert.sh
cd ..

cp -r certs APs/config/certs
cp -r certs Clients/config/certs