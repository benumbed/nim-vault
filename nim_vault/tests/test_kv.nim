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
        let kvPath = "/unit-tests/kvRead"
        discard vc.kvWrite(%*{"secret_value": "secret"}, kvPath=kvPath)

        let cfg = vc.kvRead(kvPath=kvPath)

        check:
            cfg.error != true
            not ("error" in cfg.response)
            cfg.response["secret_value"].getStr == "secret"
            

    test "kvRead throws for non-existent paths":
        expect VaultNotFoundError:
            discard vc.kvRead()
            discard vc.kvRead(mountpoint="")
            discard vc.kvRead(kvPath="")


    test "kvWrite throws for non-existent paths":
        expect VaultNotFoundError:
            discard vc.kvWrite(JsonNode(), mountpoint="banana", kvPath="foo")


    test "kvWrite can write to a path":
        let data = %*{
            "secret_value": "secret"
        }
        let res =  vc.kvWrite(data, kvPath="/unit-tests")

        check:
            "created_time" in res.response
            res.response["destroyed"].getBool == false


    test "kvDelete deletes the provided secret":
        let kvPath = "/unit-tests/kvDelete"
        discard vc.kvWrite(%*{"secret_value": "secret"}, kvPath=kvPath)
        let resp = vc.kvRead(kvPath=kvPath).response
        check:
            "secret_value" in resp

        discard vc.kvDelete(kvPath=kvPath)

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath)


    test "kv2DeleteVersions only deletes the specified versions":
        let kvPath = "/unit-tests/kv2DeleteVersions"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret2"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret3"}, kvPath=kvPath)

        let res = vc.kv2DeleteVersions(kvPath=kvPath, versions=[1, 3])

        check:
            res.error == false
            res.response == nil

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath, version=1)
            discard vc.kvRead(kvPath=kvPath, version=3)

        let readRes = vc.kvRead(kvPath=kvPath, version=2)
        check:
            "secret_value" in readRes.response
            readRes.response["secret_value"].getStr == "secret2"
            readRes.error == false


    test "kv2Undelete only undeletes the specified versions":
        let kvPath = "/unit-tests/kv2Undelete"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret2"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret3"}, kvPath=kvPath)

        discard vc.kv2DeleteVersions(kvPath=kvPath, versions=[1, 3])

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath, version=1)
            discard vc.kvRead(kvPath=kvPath, version=3)

        let res = vc.kv2Undelete(kvPath=kvPath, versions=[1])
        check:
            res.response == nil
            res.error == false

        let readRes = vc.kvRead(kvPath=kvPath, version=1)
        check:
            "secret_value" in readRes.response
            readRes.response["secret_value"].getStr == "secret1"
            readRes.error == false


    test "kv2Destroy permanently deletes secrets":
        let kvPath = "/unit-tests/kv2Destroy"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret2"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret3"}, kvPath=kvPath)

        discard vc.kv2Destroy(kvPath=kvPath, versions=[2, 3])

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath, version=2)
            discard vc.kvRead(kvPath=kvPath, version=3)

        discard vc.kv2Undelete(kvPath=kvPath, versions=[2])

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath, version=2)


    test "kvList lists all secrets at a path":
        let kvPath = "/unit-tests/kvList"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1", "another_secret": "yep"}, kvPath=kvPath)

        let res = vc.kvList(kvPath="/unit-tests")

        check:
            res.error == false
            "keys" in res.response
            res.response["keys"].contains(newJString("kvList"))


    test "kv2ReadMetadata returns the metadata for a path":
        let kvPath = "/unit-tests/kvReadMetadata"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1"}, kvPath=kvPath)

        let res = vc.kv2ReadMetadata(kvPath=kvPath)

        check:
            res.error == false
            res.response["current_version"].getInt == 1
            res.response["delete_version_after"].getStr == "0s"
            res.response["max_versions"].getInt == 0
            "versions" in res.response
            "1" in res.response["versions"]

    test "kv2UpdateMetadata updates the metadata settings for a secret":
        let kvPath = "/unit-tests/kvUpdateMetadata"
        discard vc.kv2DeleteAll(kvPath=kvPath)  # Clear all versions from previous test
        discard vc.kvWrite(%*{"secret_value": "secret1"}, kvPath=kvPath)

        let res = vc.kv2ReadMetadata(kvPath=kvPath)

        check:
            res.error == false
            res.response["current_version"].getInt == 1
            res.response["delete_version_after"].getStr == "0s"
            res.response["max_versions"].getInt == 0
            "versions" in res.response
            "1" in res.response["versions"]

        discard vc.kv2UpdateMetadata(kvPath=kvPath, maxVersions=10, casRequired=true, deleteVersionAfter="1h")

        let resAfter = vc.kv2ReadMetadata(kvPath=kvPath)

        check:
            resAfter.error == false
            resAfter.response["current_version"].getInt == 1
            resAfter.response["delete_version_after"].getStr == "1h0m0s"
            resAfter.response["cas_required"].getBool == true
            resAfter.response["max_versions"].getInt == 10
            "versions" in res.response
            "1" in res.response["versions"]


    test "kv2DeleteAll will delete all versions of a secret":
        let kvPath = "/unit-tests/kv2DeleteAll"
        discard vc.kvWrite(%*{"secret_value": "secret"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret"}, kvPath=kvPath)
        discard vc.kvWrite(%*{"secret_value": "secret"}, kvPath=kvPath)

        let res = vc.kv2DeleteAll(kvPath=kvPath)

        check:
            res.error == false
            res.response == nil

        expect VaultNotFoundError:
            discard vc.kvRead(kvPath=kvPath)