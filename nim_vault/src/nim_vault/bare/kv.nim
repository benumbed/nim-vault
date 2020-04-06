## 
## Provides a very basic wrapper over the top of the `kv` and `kv2` APIs.  kv2 currently has highest priority, as it
## is the most popular.
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat
import strutils

import ./connection
import ./errors
import ../structs

proc kvSetConfig*(this: VaultConnection, mountpoint="/secret", max_versions=0, cas_required=false, 
                  delete_version_after="0s"): JsonWithErrorIndicator =
    ## Wrapper method for `/secret/config` where 'secret' is the mountpoint of a kv2 engine. `mountpoint` is the root
    ## of the kv or kv2 engine.
    let call_body = $(%*{
        "max_versions": max_versions,
        "cas_required": cas_required,
        "delete_version_after": delete_version_after
    })
    
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/config"), body = call_body)

    var has_error = false
    var resp_json: JsonNode = nil
    if res.code != Http204:
        has_error = true
        resp_json = res.body().parseJson()
    
    return (resp_json, has_error)


proc kvGetConfig*(this: VaultConnection, mountpoint="/secret"): JsonWithErrorIndicator =
    ## Wrapper method for `/secret/config` where 'secret' is the mountpoint of a kv2 engine. `mountpoint` is the root
    ## of the kv or kv2 engine.
    let res = this.client.get(url = this.api_path(fmt"{mountpoint}/config"))

    var has_error = false
    let resp_json = res.body().parseJson()
    if res.code != Http200 or not ("data" in resp_json):
        has_error = true

    return (resp_json["data"], has_error)
 

proc kvPathGenerator(mountpoint="/secret", kv_path="/", isKv2=true): string =
    let kv2data = if isKv2: "data" else: ""
    let pathLeadingSlash = if kv_path.startsWith("/"): "" else: "/"
    result = fmt"/{mountpoint}/{kv2data}{pathLeadingSlash}{kv_path}"


proc kvRead*(this: VaultConnection, mountpoint="/secret", kv_path="/", isKv2=true): JsonWithErrorIndicator =
    ## Reads the secret at the provided `kv_path` on the provided `mountpoint`.  If `isKv2` is set to false, the 
    ## procedure will assume it is reading from an original kv secrets engine.
    let url = this.api_path(kvPathGenerator(mountpoint, kv_path, isKv2))
    let res = this.client.get(url = url)

    var has_error = false
    let resp_json = res.body().parseJson()

    if res.code == Http404:
        raise newException(VaultNotFoundError, fmt"The path '{url}' was not found")

    if res.code != Http200 or not ("data" in resp_json):
        has_error = true

    return ((if isKv2: resp_json["data"]["data"] else: resp_json["data"]), has_error)


proc kvWrite*(this: VaultConnection, data: JsonNode, mountpoint="/secret", kv_path="/", isKv2=true): JsonWithErrorIndicator =
    ## Writes to the secret at the provided `kv_path` on the provided `mountpoint`.  If `isKv2` is set to false, the 
    ## procedure will assume it is writing to an original kv secrets engine.
    let url = this.api_path(kvPathGenerator(mountpoint, kv_path, isKv2))
    let res = this.client.post(url = url, body = $(%*{"data": data}))

    var has_error = false
    let resp_json = res.body().parseJson()

    if res.code == Http404:
        raise newException(VaultNotFoundError, fmt"The path '{url}' was not found")

    if res.code != Http200 or not ("data" in resp_json):
        has_error = true
    
    let resp = if "data" in resp_json: resp_json["data"] else: resp_json
    return (resp, has_error)