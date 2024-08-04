## 
## Wraps the `token` API methods from Vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import tables

import ../connection
import ../../types
import ../../utils

type TokenOptions* = object
    id: string
    role_name: string
    policies: openArray[string]
    meta: Table[string,string]
    no_parent: bool
    no_default_policy: bool
    renewable: bool
    lease: string
    ttl: string
    tokType: string
    explicit_max_ttl: string
    display_name: string
    num_uses: int
    period: string
    entity_alias: string

proc tokListAccessors*(vc: VaultConnection): JsonWithErrorIndicator =
    ## Wraps the token list accessor API method
    let res = vc.client.get(url = vc.api_path("/auth/token/accessors"))

    return expectHttp200(res, "/auth/token/accessors", isKv2=false)

proc tokCreate*(vc: VaultConnection): JsonWithErrorIndicator =
    ## Wraps the token create API method