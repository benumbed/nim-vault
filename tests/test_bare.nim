## 
## Tests for the `bare` Vault API
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
## NOTE: These tests assume you're running Vault locally on port 8200 (Docker).
## In the future they will automatically spin a Vault docker container, once I port that code
## over.
import json
import os
import strformat
import unittest

import nim_vault/bare/connection

let VAULT_URL = "http://localhost:8200"

suite "Connection Module Tests":

    test "newConnection creates a new Vault connection":
        var conn = newVaultConnection(VAULT_URL)

        check conn.vault_url == fmt"{VAULT_URL}/v1"
        check conn.vault_token == os.getEnv("VAULT_TOKEN")


    test "login method works with valid token":
        var conn = newVaultConnection(VAULT_URL)

        var result = conn.login()

        check result.kind == JObject
        check result["errors"].kind == JArray
        check result["errors"].len == 0

    test "api_path returns full, properly formed path to Vault API resource":
        let conn = newVaultConnection(VAULT_URL)

        let path = conn.api_path("/blah")
        check path == fmt"{VAULT_URL}/v1/blah"

    test "approle_login works with valid role and secret id's":
        let implement_me = true