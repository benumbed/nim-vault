## creds.nim
##
## Methods to help with credentials management in Vault
##
## Author: Nick Whalen <purplxed@purplxed.dev>
## (Copyright (c) 2024 Nick Whalen. All Rights Reserved.)
##
import ./connection.nim
import std/json
import std/strformat

proc getRabbitMqCreds*(vault: var VaultConnection, roleName: string, mountpoint = "rabbitmq"): JsonNode =
  ## Uses the rabbitmq auth plugin to create a new pair of credentials for RabbitMQ based on the provided role
  ##
  vault.get(fmt"/{mountpoint}/creds/{roleName}")

