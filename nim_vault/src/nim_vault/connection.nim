## 
## Provides connection stuff
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import httpclient
import json
import os

import ./errors

type VaultConnectionError = object of VaultError

type VaultConnection* = ref object of RootObj
    vault_url*: string
    vault_token*: string
    connection*: HttpClient
method api_path(this: VaultConnection, path_frag: string): string {.base.} = 
    fmt"{this.vault_url}/{path_frag}"
    

proc newVaultConnection*(vault_url: string, vault_token = os.getEnv("VAULT_TOKEN", "")): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)
    new result
    
    result.connection = newHttpClient("nim_vault")
    result.connection.headers.add("X-Vault_Token", vault_token)
    result.vault_url = fmt"{vault_url}/v1"
    result.vault_token = vault_token


proc login*(vault: VaultConnection): json.JsonNode =
    var resp: Response
    try:
        resp = vault.connection.get(vault.vault_url)
    except Exception as e:
        raise newException(VaultConnectionError, fmt"Failed to communicate with Vault: {e.msg}")
        
    if resp.contentType != "application/json":
        raise newException(VaultConnectionError, "The content type returned from Vault was not JSON!")

    return json.parseJson(resp.bodyStream)
