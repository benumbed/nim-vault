## Main API interface for Vault
## Copyright 2019 Benumbed <benumbed@projectneutron.com>

import httpclient
import json
import os
import strformat
import system

type VaultConnection* = object
    vault_url*: string
    vault_token*: string
    connection*: HttpClient

type VaultError = object of system.Exception

proc newConnection*(vault_url: string, vault_token = os.getEnv("VAULT_TOKEN", "")): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)

    result.connection = newHttpClient("nim_vault")
    result.connection.headers.add("X-Vault_Token", vault_token)
    result.vault_url = fmt"{vault_url}/v1"
    result.vault_token = vault_token

proc login*(vault: VaultConnection): JsonNode =
    ## This method merely attempts to log in to Vault to ensure the stored token works
    ##

    var resp: Response
    try:
        resp = vault.connection.get(vault.vault_url)
    except Exception as e:
        raise newException(VaultError, fmt"Failed to communicate with Vault: {e.msg}")
        
    if resp.contentType != "application/json":
        raise newException(VaultError, "The content type returned from Vault was not JSON!")

    return json.parseJson(resp.bodyStream)
 