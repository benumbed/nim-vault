## 
## Tests for the pki wrapper
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
## NOTE: These tests assume you're running Vault locally on port 8200 (Docker).
## 
import json
import os
import strutils
import unittest

import nim_vault/bare/connection
import nim_vault/bare/secrets/pki

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

## Setup for this test suite:
## WARNING: You're generating cryptographic secrets with this test -- Don't use a prod Vault instance!
## 
## You'll need to configure a PKI secrets mount at '/pki' on your dev Vault instance. 
## Create a new root CA and set it to expire a few years in the future
## Create a new role named `nim-vault-tests` and set the TTL to something less than the CA TTL (actually set the TTL, 
##  if you're using the UI, it may look like the TTL is set to 30 seconds in the form, it is not)

suite "Tests for bare PKI wrapper":
    test "Can rotate CRLs":
        let pkiRes = vc.pkiRotateCrls()
        
        check:
            pkiRes.error != true
            pkiRes.response.contains("success")
            pkiRes.response["success"].getBool == true

    test "Can issue new TLS certificate and private key":
        let pkiRes = vc.pkiGenerate("nim-vault-tests", "nim-vault.test")

        check:
            pkiRes.error != true
            pkiRes.response.contains("certificate")
            pkiRes.response.contains("private_key")

            pkiRes.response["private_key_type"].getStr == "rsa"
            pkiRes.response["private_key"].getStr.contains("-----BEGIN RSA PRIVATE KEY-----")
            pkiRes.response["certificate"].getStr.contains("-----BEGIN CERTIFICATE-----")

    test "Can sign provided CSR":
        let pkiRes = vc.pkiSignCertificate("nim-vault-tests", "<CSR TODO>", "nim-vault.test")

        check:
            pkiRes.error != true
            pkiRes.response.contains("certificate")
            pkiRes.response["certificate"].getStr.contains("-----BEGIN CERTIFICATE-----")
