## Main API interface for Vault
## Copyright 2019 Benumbed <benumbed@projectneutron.com>

import httpclient
import os
import strformat
import system

import nim_vault/utils
import nim_vault/errors
import nim_vault/bare/connection
import nim_vault/utils/tokens

proc newConnection*(vault_url: string, vault_token = ""): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)
    new result

    # var tok = vault_token
    # if tok.isEmpty:
    #     let foundToken = findVaultToken()
    #     if foundToken[1]:
    #         tok = foundToken[0]
    #     else:
    #         raise newException(VaultTokenError, "Vault token was empty")
    
    # result.connection = newHttpClient("nim_vault")
    # result.connection.headers.add("X-Vault_Token", vault_token)
    # result.vault_url = fmt"{vault_url}/v1"
    # result.vault_token = vault_token
