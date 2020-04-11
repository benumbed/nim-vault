## 
## Tests for the policy wrapper
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
## NOTE: These tests assume you're running Vault locally on port 8200 (Docker).
## In the future they will automatically spin a Vault docker container, once I port that code
## over.
import json
import os
import unittest

import nim_vault/errors
import nim_vault/bare/sys/policy
import nim_vault/bare/connection

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

suite "Policies API wrapper tests":
    test "policiesAclList lists ACL policies":
        let res = vc.policiesAclList()
        let keys = res.response["keys"]

        check:
            res.error == false
            keys.contains(newJString("default"))
            keys.contains(newJString("root"))
    
    test "policiesAclRead reads an ACL policy":
        let res = vc.policiesAclRead("default")

        check:
            res.error == false
            "policy" in res.response

        # TODO: Parse the HCL? (no Nim HCL parser yet)
