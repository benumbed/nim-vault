## 
## Wraps the `userpass` API methods from Vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat

import ../connection
import ../../structs
import ../../utils


proc userCreateUpdate*(vc: VaultConnection, 
                        username: string,
                        password: string = "",
                        tokenTtl: string = "",
                        tokenMaxTtl: string = "",
                        tokenPolicies: seq[string] = @[],
                        tokenBoundCidrs: seq[string] = @[],
                        tokenExplicitMaxTtl: string = "",
                        tokenNoDefaultPolicy: bool = false,
                        tokenNumUses: int = 0,
                        tokenPeriod: string = "",
                        tokenType: string = "",
                        mountpoint = "/auth/userpass"
                        ): JsonWithErrorIndicator =
    ## Wraps the user create/update method
    ## https://www.vaultproject.io/api-docs/auth/userpass#create-update-user
    let callBody = $(%*{
        "password": password,
        "token_ttl": tokenTtl,
        "token_max_ttl": tokenMaxTtl,
        "token_policies": tokenPolicies,
        "token_bound_cidrs": tokenBoundCidrs,
        "token_explicit_max_ttl": tokenExplicitMaxTtl,
        "token_no_default_policy": tokenNoDefaultPolicy,
        "token_num_uses": tokenNumUses,
        "token_period": tokenPeriod,
        "token_type": tokenType
    })
    
    let url = vc.api_path(fmt"{mountpoint}/users/{username}")
    let res = vc.client.post(url = url, body = callBody)

    return expectHttp204(res)


proc userRead*(vc: VaultConnection, username: string, mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user read method
    ## https://www.vaultproject.io/api-docs/auth/userpass#read-user
    let url = vc.api_path(fmt"{mountpoint}/users/{username}")
    let res = vc.client.get(url = url)

    return expectHttp200(res, url)


proc userDelete*(vc: VaultConnection, username: string, mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user delete method
    ## https://www.vaultproject.io/api-docs/auth/userpass#delete-user
    let res = vc.client.delete(url = vc.api_path(fmt"{mountpoint}/users/{username}"))

    return expectHttp204(res)


proc userUpdatePassword*(vc: VaultConnection, username: string, password: string, 
                         mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user password update method
    ## https://www.vaultproject.io/api-docs/auth/userpass#update-password-on-user
    let callBody = $(%*{
        "password": password
    })
    let res = vc.client.post(url = vc.api_path(fmt"{mountpoint}/users/{username}/password"), body = callBody)

    return expectHttp204(res)


proc userUpdatePolicies*(vc: VaultConnection, username: string, policies: seq[string], 
                         mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user policy update method
    ## https://www.vaultproject.io/api-docs/auth/userpass#update-policies-on-user
    let callBody = $(%*{
        "policies": policies
    })
    let res = vc.client.post(url = vc.api_path(fmt"{mountpoint}/users/{username}/policies"), body = callBody)

    return expectHttp204(res)


proc userList*(vc: VaultConnection, mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user list method
    ## https://www.vaultproject.io/api-docs/auth/userpass#list-users
    let url = vc.api_path(fmt"{mountpoint}/users")
    let res = vc.client.list(url = url)

    return expectHttp200(res, url)


proc userLogin*(vc: VaultConnection, username: string, password: string, 
                mountpoint="/auth/userpass"): JsonWithErrorIndicator =
    ## Wraps the user login method
    ## https://www.vaultproject.io/api-docs/auth/userpass#login
    let callBody = $(%*{
        "password": password
    })
    let url = vc.api_path(fmt"{mountpoint}/login/{username}")
    let res = vc.client.post(url = url, body = callBody)

    return expectHttp200(res, url, returnAll = true)