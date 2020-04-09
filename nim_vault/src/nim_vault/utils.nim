## 
## Helpful utilities
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat
import strutils

import ./errors
import ./structs

proc expectHttp204*(res: Response): JsonWithErrorIndicator =
    ## HTTP 204 common-case handler
    if res.code != Http204:
        return (res.body().parseJson(), true)
    
    return (JsonNode(nil), false)


proc expectHttp200*(res: Response, url: string, isKv2: bool, hasSingleData = false): JsonWithErrorIndicator =
    ## Collects all the common HTTP 200 code among the kv methods
    if res.code == Http404:
        raise newException(VaultNotFoundError, fmt"The path '{url}' was not found")

    let resp_json = res.body().parseJson()

    if res.code != Http200 or not ("data" in resp_json):
        return (resp_json, true)
    else:
        return ((if isKv2 and not hasSingleData: resp_json["data"]["data"] else: resp_json["data"]), false)


proc singleLine*(this: string): string =
    ## Takes a multi-line string collapses it
    var toks: seq[string]

    for tok in this.split("\n"):
        toks.add(tok.strip())

    result = toks.join(" ")
