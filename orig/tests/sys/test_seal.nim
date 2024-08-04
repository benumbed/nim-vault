## 
## Tests for the /sys/[un]seal* wrappers
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
## NOTE: These tests assume you're running Vault locally on port 8200 (Docker).
## 
import json
import os
import unittest

import nim_vault/bare/connection
import nim_vault/bare/sys/seal

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

# NOTE: You'll need to set 'VAULT_UNSEAL_KEY' for these tests to work.  They assume a dev vault instance with only a 
#   single key needed for unseal.

suite "Tests for seal/unseal sys API wrapper":
    test "Can fetch seal status":
        let res = vc.sysSealStatus()
       
        check:
            res.error != true
            res.response.contains("sealed")
            res.response.contains("t")
            res.response.contains("n")


    test "Can submit unseal key to Vault":
        let res = vc.sysUnseal(key=os.getEnv("VAULT_UNSEAL_KEY"))
        
        check:
            res.error != true
            res.response.contains("sealed")
            res.response.contains("t")
            res.response.contains("n")
            res.response["sealed"].getBool == false

    test "Can seal the Vault":
        let res = vc.sysSeal()
        
        check:
            res.error != true

        discard vc.sysUnseal(key=os.getEnv("VAULT_UNSEAL_KEY"))