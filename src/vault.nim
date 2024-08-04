## vault.nim
##
## Provides the main interface to the Vault library
##
## Author: Nick Whalen <purplxed@purplxed.dev>
## (Copyright (c) 2024 Nick Whalen. All Rights Reserved.)
##
include ./connection.nim

proc getBlock*(vault: VaultConnection, mountpoint: string, path: string): JsonNode =
  ## Fetches a JSON block from a KV2 store in Vault
  ##
  vault.get(fmt"/{mountpoint}/data/{path}")


