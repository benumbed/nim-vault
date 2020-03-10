## Main API interface for Vault
## Copyright 2019 Benumbed <benumbed@projectneutron.com>

import httpclient
import os
import strformat
import system

import nim_vault/connection

proc newConnection*(vault_url: string, vault_token = os.getEnv("VAULT_TOKEN", "")): VaultConnection =
    ## Creates a new Vault connection object (does not actually connect, that is done lazily)
    new result
    
    result.connection = newHttpClient("nim_vault")
    result.connection.headers.add("X-Vault_Token", vault_token)
    result.vault_url = fmt"{vault_url}/v1"
    result.vault_token = vault_token
