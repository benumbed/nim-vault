## 
## Tests for the userpass wrapper
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
import nim_vault/bare/auth/userpass
import nim_vault/bare/connection

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

suite "Userpass API wrapper tests":
    test "userCreateUpdate can create a new user":
        let res = vc.userCreateUpdate(
            "unittest-user",
            "test123",
            "1m",
            "10m",
            @["default"],
            @["127.0.0.1/32"],
            "15m",
            true,
            1,
            "20m",
            "service"
        )

        check:
            res.error == false

        let user = vc.userRead("unittest-user")
        let expected = "{\"token_bound_cidrs\":[\"127.0.0.1\"],\"token_explicit_max_ttl\":900,\"token_max_ttl\":600,\"token_no_default_policy\":true,\"token_num_uses\":1,\"token_period\":1200,\"token_policies\":[\"default\"],\"token_ttl\":60,\"token_type\":\"service\"}"
        let expectedJson = json.parseJson(expected)

        check:
            res.error == false
            user.response == expectedJson
    
    test "attempting to fetch an invalid user results in a 404":
        expect VaultNotFoundError:
            discard vc.userRead("baduser")
    
    test "userDelete actually deletes the user":
        discard vc.userCreateUpdate("delete-me", "do-eet")

        discard vc.userRead("delete-me") # This will throw if the user DNE

        discard vc.userDelete("delete-me")

        expect VaultNotFoundError:
            discard vc.userRead("delete-me")

    test "userUpdatePassword updates the user's password":
        discard vc.userCreateUpdate("password-user", "oldpassword")

        var res = vc.userLogin("password-user", "oldpassword")
        check:
            res.error == false
            res.response["auth"]["metadata"]["username"].getStr == "password-user"

        discard vc.userUpdatePassword("password-user", "newpassword")

        let res2 = vc.userLogin("password-user", "newpassword")
        let resBad = vc.userLogin("password-user", "oldpassword")
        check:
            res2.error == false
            res2.response["auth"]["metadata"]["username"].getStr == "password-user"

            resBad.error == true
            resBad.response["errors"].contains(newJString("invalid username or password"))

    test "userList shows expected users":
        discard vc.userCreateUpdate("list-user", "listpassword")

        let res = vc.userList()

        check:
            res.error == false
            res.response["keys"].contains(newJString("list-user"))
