## 
## Provides the `VaultConnection` object, along with methods which manipulate it
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import os
import strformat
import strutils

import nim_vault/errors
import nim_vault/structs

type VaultConnectionError* = object of VaultError
type VaultConnection* = ref object of RootObj
    vault_url*: string
    vault_token*: string
    vault_token_info: JsonNode
    client*: HttpClient


method api_path*(this: VaultConnection, path_frag: string): string {.base.} = 
    ## Simply returns a fully-formed API url given the provided `path_frag`
    let clean_frag = path_frag.strip(leading=true, trailing=false, chars={'/'})
    fmt"{this.vault_url}/{clean_frag}"

method approle_login*(this: VaultConnection, role_id: string, secret_id: string): StrWithError {.base.} = 
    ## Will take the provided `role_id` and `secret_id` and use them to log in to Vault and acquire a token, which will
    ## then be stored for the current connection.
    let vault_path = this.api_path("auth/approle/login")

    let call_body = $(%*{
        "role_id": role_id,
        "secret_id": secret_id
    })
    
    let res = this.client.post(url=vault_path, body=call_body)

    var resp_json = res.body().parseJson()
    if res.code != Http200:
        return(fmt"""Failed to use AppRole to login to {vault_path}: {resp_json["errors"]}""", true)

    if "auth" notin resp_json or "client_token" notin resp_json["auth"]:
        return ("Invalid response from Vault, did not find the expected keys", true)

    let auth_blk = resp_json["auth"]

    this.vault_token = auth_blk["client_token"].getStr()
    this.vault_token_info = auth_blk

    return (this.vault_token, false)

method login*(this: VaultConnection): json.JsonNode {.base.} =
    var resp: Response
    try:
        resp = this.client.get(this.vault_url)
    except Exception as e:
        raise newException(VaultConnectionError, fmt"Failed to communicate with Vault: {e.msg}")
        
    if resp.contentType != "application/json":
        raise newException(VaultConnectionError, "The content type returned from Vault was not JSON!")

    return json.parseJson(resp.bodyStream)



proc newVaultConnection*(vault_url: string, vault_token = os.getEnv("VAULT_TOKEN", ""), api_version = "v1"): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)
    let clean_vault_url = vault_url.strip(leading=false, trailing=true, chars={'/'})

    new result
    result.client = newHttpClient("nim_vault")
    result.client.headers.add("Authorization", fmt"Bearer {vault_token}")
    result.client.headers.add("Accept", "application/json")
    result.client.headers.add("Content-Type", "application/json")
    result.vault_url = fmt"{clean_vault_url}/{api_version}"
    result.vault_token = vault_token
