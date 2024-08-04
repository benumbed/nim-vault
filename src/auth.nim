## auth.nim
##
## Convienence methods to interface with Vault's auth methods
##
## Author: Nick Whalen <purplxed@purplxed.dev>
## (Copyright (c) 2024 Nick Whalen. All Rights Reserved.)
##
import ./connection.nim
import std/json
import std/paths
import std/strformat

proc userPassLogin*(vault: var VaultConnection, username: string, password: string) =
  ## Logs in using a username and password
  ##
  discard vault.post(fmt"/auth/userpass/login/{username}", %*{"password": password}) 

proc tokenLogin*(vault: var VaultConnection, token: string) =
  ## Logs in using a standard Vault token
  ##
  vault.setToken(token)

proc tlsLogin*(vault: var VaultConnection, certificate, key: Path, role = "") =
  ## Logs in using an x509 keypair. Note that this will tear down the original Vault connection and create a new one
  ##
  vault.upgradeToMtls(key, certificate)
  discard vault.post(fmt"/auth/cert/login", %*{"name": role})


