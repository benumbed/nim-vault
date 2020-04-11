## 
## Wrapps the `/sys/policy` and `/sys/policies` API methods from Vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import json
import httpclient
import strformat
import tables

import ../connection
import ../../structs
import ../../utils

proc policiesAclList*(vc: VaultConnection): JsonWithErrorIndicator = 
    ## Wraps the ACL policy listing endpoint
    ## https://www.vaultproject.io/api-docs/system/policies/#list-acl-policies
    let url = vc.api_path("/sys/policies/acl")
    let res = vc.client.request(url = url, httpMethod = "LIST")

    return expectHttp200(res, url, isKv2=false)

proc policiesAclRead*(vc: VaultConnection, policyName: string): JsonWithErrorIndicator = 
    ## Wraps the ACL policy listing endpoint
    ## https://www.vaultproject.io/api-docs/system/policies/#read-acl-policy
    let url = vc.api_path(fmt"/sys/policies/acl/{policyName}")
    let res = vc.client.get(url = url)

    return expectHttp200(res, url, isKv2=false)
