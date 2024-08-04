## 
## Handles endpoints which deal with sealing/unsealing a Vault host
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json

import ../connection
import ../../utils
import ../../types


proc sysSealStatus*(this: VaultConnection): JsonWithErrorIndicator =
    ## Fetches the status of the Vault seal
    ## https://www.vaultproject.io/api-docs/system/unseal#sys-unseal
    ##
    return expectHttp200_NoDataBlock(this.client.get(this.api_path("/sys/seal-status")))

proc sysSeal*(this: VaultConnection): JsonWithErrorIndicator =
    ## Seals the Vault
    ## https://www.vaultproject.io/api-docs/system/seal#sys-seal
    ##
    return expectHttp204(this.client.put(this.api_path("/sys/seal")))

proc sysSealwrapRewrap*(this: VaultConnection): JsonWithErrorIndicator =
    ## Re-wrap all seal wrapped entries (ENTERPRISE ONLY, NO TESTS)
    ## https://www.vaultproject.io/api-docs/system/sealwrap-rewrap#sys-sealwrap-rewrap
    ##
    return expectHttp200(this.client.put(this.api_path("/sys/sealwrap/rewrap")))

proc sysUnseal*(this: VaultConnection, key: string = "", reset: bool = false, migrate: bool = false): 
               JsonWithErrorIndicator =
    ## Submits an unseal key to Vault
    ## https://www.vaultproject.io/api-docs/system/unseal#sys-unseal
    ##
    let callBody = %*{
        "key": key,
        "reset": reset,
        "migrate": migrate
    }
    return expectHttp200_NoDataBlock(this.client.put(this.api_path("/sys/unseal"), body = $callBody))