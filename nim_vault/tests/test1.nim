# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.
import json
import os
import strformat
import unittest

import nim_vault as vault

suite "Test nim-vault API":

    test "newConnection":
        var vault_url = "http://localhost:8200"
        # FIXME: This is a temp dev token, set this from the environment
        var conn = vault.newConnection(vault_url)

        check conn.vault_url == fmt"{vault_url}/v1"
        check conn.vault_token == os.getEnv("VAULT_TOKEN")


    test "test login":
        var conn = vault.newConnection("http://localhost:8200")

        var result = conn.login()

        check result.kind == JObject
        check result["errors"].kind == JArray
        check result["errors"].len == 0
