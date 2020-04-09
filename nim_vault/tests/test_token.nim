## 
## Tests for the token auth wrapper
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
import nim_vault/bare/auth/token
import nim_vault/bare/connection

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

suite "Token API wrapper tests":
    test "tokListAccessors lists token accessors":
        # Vault will 404 if there are no accessors
        expect VaultNotFoundError:
            discard vc.tokListAccessors()