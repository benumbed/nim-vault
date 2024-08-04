## 
## Provides the `VaultConnection` object, along with methods which manipulate it
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat
import strutils

import nim_vault/errors
import nim_vault/types
import nim_vault/utils
import nim_vault/utils/tokens

type VaultConnectionError* = object of VaultError
type VaultConnection* = ref object of RootObj
    vaultUrl*: string
    vaultToken*: string
    vaultTokenInfo: JsonNode
    client*: HttpClient


method api_path*(this: VaultConnection, path_frag: string): string {.base.} = 
    ## Simply returns a fully-formed API url given the provided `path_frag`
    let clean_frag = path_frag.strip(leading=true, trailing=false, chars={'/'})
    fmt"{this.vaultUrl}/{clean_frag}"

method approle_login*(this: VaultConnection, roleId: string, secretId: string): StrWithErrorIndicator {.base.} = 
    ## Will take the provided `roleId` and `secretId` and use them to log in to Vault and acquire a token, which will
    ## then be stored for the current connection.
    let vaultPath = this.api_path("auth/approle/login")

    let callBody = $(%*{
        "role_id": roleId,
        "secret_id": secretId
    })
    
    let resp = this.client.post(url=vaultPath, body=callBody)

    var respJson = resp.body().parseJson()
    if resp.code != Http200:
        return(fmt"""Failed to use AppRole to login to {vaultPath}: {respJson["errors"]}""", true)

    if "auth" notin respJson or "client_token" notin respJson["auth"]:
        return ("Invalid response from Vault, did not find the expected keys", true)

    let authBlk = respJson["auth"]

    this.vaultToken = authBlk["client_token"].getStr()
    this.vaultTokenInfo = authBlk

    return (this.vaultToken, false)

method login*(this: VaultConnection): StrWithErrorIndicator {.base.} =
    ## This doesn't actually run a `login` like you would expect, it just validates the token attached to the 
    ## VaultConnection object
    ## 
    if this.vaultToken.isEmpty:
        return ("No Vault token attached to connection", true)
    
    var resp: Response
    let checkBody = $(%*{
        "paths": ["sys/capabilities-self"]
    })
    try:
        resp = this.client.post(fmt"{this.vaultUrl}/sys/capabilities-self", body=checkBody)
    except Exception as e:
        raise newException(VaultConnectionError, fmt"Failed to communicate with Vault: {e.msg}")

    if resp.contentType != "application/json":
        raise newException(VaultConnectionError, "The content type returned from Vault was not JSON!")
    elif resp.code != Http200:
        return (fmt"Unexpected HTTP status code: {resp.code}", true)

    let res_json = resp.body.parseJson()
    let errs = res_json.stringifyVaultErrors()
    return (errs, if errs.isEmpty: false else: true)

proc newVaultConnection*(vaultUrl: string, vaultToken = "", apiVersion = "v1"): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)
    let cleanVaultUrl = vaultUrl.strip(leading=false, trailing=true, chars={'/'})
    new result

    result.client = newHttpClient("nim_vault")
    result.vaultToken = if not vaultToken.isEmpty: vaultToken else: findVaultToken().output
    result.client.headers.add("Authorization", fmt"Bearer {result.vaultToken}")
    result.client.headers.add("Accept", "application/json")
    result.client.headers.add("Content-Type", "application/json")
    result.vaultUrl = fmt"{cleanVaultUrl}/{apiVersion}"
