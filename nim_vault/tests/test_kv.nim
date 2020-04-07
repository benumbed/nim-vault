## 
## Tests for the kv/kv2 wrapper
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
## NOTE: These tests assume you're running Vault locally on port 8200 (Docker).
## In the future they will automatically spin a Vault docker container, once I port that code
## over.
import json
import os
import unittest

import nim_vault/bare/connection
import nim_vault/bare/errors
import nim_vault/bare/kv

let VAULT_ADDR =os.getEnv("VAULT_ADDR", "http://localhost:8200")
let vc = newVaultConnection(VAULT_ADDR)

suite "Bare Wrapper for kv/kv2":
    test "kvSet/GetConfig works as expected":
        let setRes = vc.kvSetConfig(max_versions=21, cas_required=true, delete_version_after="10h")
        let cfg = vc.kvGetConfig()

        check:
            setRes.error != true
            setRes.response == nil
            cfg.response["max_versions"].getInt == 21
            cfg.response["cas_required"].getBool == true
            cfg.response["delete_version_after"].getStr == "10h0m0s"

        discard vc.kvSetConfig(max_versions=0, cas_required=false, delete_version_after="0h")
    

    test "kvRead returns config for kv2 mountpoint":
        let kv_path = "/unit-tests/kvRead"
        discard vc.kvWrite(%*{"secret_value": "secret"}, kv_path=kv_path)

        let cfg = vc.kvRead(kv_path=kv_path)

        check:
            cfg.error != true
            not ("error" in cfg.response)
            cfg.response["secret_value"].getStr == "secret"
            

    test "kvRead throws for non-existent paths":
        expect VaultNotFoundError:
            discard vc.kvRead()
            discard vc.kvRead(mountpoint="")
            discard vc.kvRead(kv_path="")


    test "kvWrite throws for non-existent paths":
        expect VaultNotFoundError:
            discard vc.kvWrite(JsonNode(), mountpoint="banana", kv_path="foo")


    test "kvWrite can write to a path":
        let data = %*{
            "secret_value": "secret"
        }
        let res =  vc.kvWrite(data, kv_path="/unit-tests")

        check:
            "created_time" in res.response
            res.response["destroyed"].getBool == false

    test "kvWrite deletes the provided secret":
        let kv_path = "/unit-tests/kvDelete"
        discard vc.kvWrite(%*{"secret_value": "secret"}, kv_path=kv_path)
        let resp = vc.kvRead(kv_path=kv_path).response
        check:
            "secret_value" in resp

        discard vc.kvDelete(kv_path=kv_path)

        expect VaultNotFoundError:
            discard vc.kvRead(kv_path=kv_path)
