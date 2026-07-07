#!/bin/bash

# Single source of truth for the lab PKI.
# The containers receive these certs at runtime via the ./certs volume mounts
# defined in the docker-compose files, so there is no need to copy the folder
# into APs/config or Clients/config.

cd certs
bash createCert.sh
cd ..
