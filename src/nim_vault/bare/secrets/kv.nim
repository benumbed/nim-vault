## 
## Provides a very basic wrapper over the top of the `kv` and `kv2` APIs.  kv2 currently has highest priority, as it
## is the most popular.  kv2-only procs are prefixed with `kv2` instead of just `kv`.
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat
import strutils

import ../connection
import ../../types
import ../../utils

#-----------------------------------------------------------------------------------------------------------------------
# Helper Methods
#-----------------------------------------------------------------------------------------------------------------------
proc kvPathGenerator(mountpoint="/secret", kvPath="/", isKv2=true): string =
    ## Generates the correct path depending on whether kv2 is in use or not
    let kv2data = if isKv2: "data" else: ""
    let pathLeadingSlash = if kvPath.startsWith("/"): "" else: "/"
    result = fmt"/{mountpoint}/{kv2data}{pathLeadingSlash}{kvPath}"    


#-----------------------------------------------------------------------------------------------------------------------
# API Methods
#-----------------------------------------------------------------------------------------------------------------------

proc kvSetConfig*(this: VaultConnection, mountpoint="/secret", maxVersions=0, casRequired=false, 
                  deleteVersionAfter="0s"): JsonWithErrorIndicator =
    ## Wrapper method for `/secret/config` where 'secret' is the mountpoint of a kv2 engine. `mountpoint` is the root
    ## of the kv or kv2 engine.
    let callBody = $(%*{
        "max_versions": maxVersions,
        "cas_required": casRequired,
        "delete_version_after": deleteVersionAfter
    })
    
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/config"), body = callBody)

    return expectHttp204(res)


proc kvGetConfig*(this: VaultConnection, mountpoint="/secret"): JsonWithErrorIndicator =
    ## Wrapper method for `/secret/config` where 'secret' is the mountpoint of a kv2 engine. `mountpoint` is the root
    ## of the kv or kv2 engine.
    let url = this.api_path(fmt"{mountpoint}/config")
    let res = this.client.get(url = url)

    return expectHttp200(res, url, isKv2=false)



proc kvRead*(this: VaultConnection, mountpoint="/secret", kvPath="/", isKv2=true, version=0): JsonWithErrorIndicator =
    ## Reads the secret at the provided `kvPath` on the provided `mountpoint`.  If `isKv2` is set to false, the 
    ## procedure will assume it is reading from an original kv secrets engine.
    let url = this.api_path(fmt"{kvPathGenerator(mountpoint, kvPath, isKv2)}?version={version}")
    let res = this.client.get(url = url)

    return expectHttp200(res, url, isKv2, hasSingleData = false)


proc kvWrite*(this: VaultConnection, data: JsonNode, mountpoint="/secret", kvPath="/", isKv2=true): JsonWithErrorIndicator =
    ## Writes to the secret at the provided `kvPath` on the provided `mountpoint`.  If `isKv2` is set to false, the 
    ## procedure will assume it is writing to an original kv secrets engine.
    let url = this.api_path(kvPathGenerator(mountpoint, kvPath, isKv2))
    let res = this.client.post(url = url, body = $(%*{"data": data}))

    return expectHttp200(res, url, isKv2, hasSingleData=true)


proc kvDelete*(this: VaultConnection, mountpoint="/secret", kvPath="/", isKv2=true): JsonWithErrorIndicator =
    ## Wraps the delete call for the kv/kv2 APIs
    let url = this.api_path(kvPathGenerator(mountpoint, kvPath, isKv2))
    let res = this.client.delete(url = url)

    return expectHttp204(res)


proc kv2DeleteVersions*(this: VaultConnection, mountpoint="/secret", kvPath="/", versions: openArray[int]): JsonWithErrorIndicator =
    ## (kv2 only)  Will delete the provided versions
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let callBody = $(%*{
        "versions": %(versions),
    })
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/delete/{path}"), body=callBody)

    return expectHttp204(res)


proc kv2Undelete*(this: VaultConnection, mountpoint="/secret", kvPath="/", versions: openArray[int]): JsonWithErrorIndicator =
    ## (kv2 only) Undeletes previously deleted versions (only works if the version has not been _destroyed_)
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let callBody = $(%*{
        "versions": %(versions),
    })
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/undelete/{path}"), body=callBody)

    return expectHttp204(res)


proc kv2Destroy*(this: VaultConnection, mountpoint="/secret", kvPath="/", versions: openArray[int]): JsonWithErrorIndicator =
    ## (kv2 only) Permanently destroys the specified `versions` at the given `kvPath`
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let callBody = $(%*{
        "versions": %(versions),
    })
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/destroy/{path}"), body=callBody)

    return expectHttp204(res)

proc kvList*(this: VaultConnection, mountpoint="/secret", kvPath="/", isKv2=true): JsonWithErrorIndicator =
    ## Lists the secrets at a location
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let mdSelect = if isKv2: "metadata/" else: ""
    let url = this.api_path(fmt("{mountpoint}/{mdSelect}{path}"))
    # NOTE: Nim's httpclient doesn't directly support 'LIST' so we use the raw `request` proc here
    let res = this.client.request(url = url, httpMethod = "LIST")

    return expectHttp200(res, url, isKv2, hasSingleData=true)


proc kv2ReadMetadata*(this: VaultConnection, mountpoint="/secret", kvPath="/"): JsonWithErrorIndicator =
    ## Lists the secrets at a location
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let url = this.api_path(fmt("{mountpoint}/metadata/{path}"))
    let res = this.client.get(url = url)

    return expectHttp200(res, url, isKv2=true, hasSingleData=true)


proc kv2UpdateMetadata*(this: VaultConnection, mountpoint="/secret", kvPath="/", maxVersions=0, casRequired=false, 
                        deleteVersionAfter="0s"): JsonWithErrorIndicator =
    ## Updates the metadata for a secret
    let callBody = $(%*{
        "max_versions": maxVersions,
        "cas_required": casRequired,
        "delete_version_after": deleteVersionAfter
    })
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let res = this.client.post(url = this.api_path(fmt"{mountpoint}/metadata/{path}"), body = callBody)

    return expectHttp204(res)


proc kv2DeleteAll*(this: VaultConnection, mountpoint="/secret", kvPath="/"): JsonWithErrorIndicator =
    ## Deletes all versions of a kv2 secret
    let path = kvPath.strip(trailing=false, chars = {'/'})
    let res = this.client.delete(url = this.api_path(fmt("{mountpoint}/metadata/{path}")))

    return expectHttp204(res)
