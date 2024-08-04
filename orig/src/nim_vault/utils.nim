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
import ./types

proc list*(client: HttpClient | AsyncHttpClient, url: string,
              httpMethod = HttpGet, body = "", headers: HttpHeaders = nil,
              multipart: MultipartData = nil): Response = 
    return client.request(url, httpMethod = "LIST", body=body, headers=headers, multipart=multipart)

proc expectHttp204*(res: Response): JsonWithErrorIndicator =
    ## HTTP 204 common-case handler
    if res.code != Http204:
        return (res.body().parseJson(), true)
    
    return (JsonNode(nil), false)

proc expectHttp200*(res: Response, isKv2: bool = false, hasSingleData = true, returnAll = false, url: string = ""): JsonWithErrorIndicator =
    let resp_json = res.body().parseJson()

    ## Collects all the common HTTP 200 code among the kv methods
    if res.code == Http404:
        var errMsg = if url.isEmptyOrWhitespace: "" else: fmt"({url}) "
        var serverError = ""
        if "errors" in resp_json and resp_json["errors"].elems.len > 0:
            serverError = resp_json["errors"].getStr()
        raise newException(VaultNotFoundError, fmt"Path not found {errMsg} {serverError}")

    if res.code != Http200 or not ("data" in resp_json):
        return (resp_json, true)
    elif returnAll:
        return (resp_json, false)
    else:
        return ((if isKv2 and not hasSingleData: resp_json["data"]["data"] else: resp_json["data"]), false)

proc expectHttp200_NoDataBlock*(res: Response, url: string = ""): JsonWithErrorIndicator =
    ## Checks for HTTP 200, but does not assume there's a 'data' key
    ##
    let resp_json = res.body().parseJson()

    ## Collects all the common HTTP 200 code among the kv methods
    if res.code == Http404:
        var errMsg = if url.isEmptyOrWhitespace: "" else: fmt"({url}) "
        var serverError = ""
        if "errors" in resp_json and resp_json["errors"].elems.len > 0:
            serverError = resp_json["errors"].getStr()
        raise newException(VaultNotFoundError, fmt"Path not found {errMsg} {serverError}")

    if res.code != Http200:
        return (resp_json, true)
    else:
        return (resp_json, false)

proc expectHttp200Raw*(res: Response, url: string = ""): StrWithErrorIndicator =
    ## Checks for HTTP 200, but doesn't assume the body is JSON
    ##
    if res.code == Http404:
        var errMsg = if url.isEmptyOrWhitespace: "" else: fmt"({url}) "
        raise newException(VaultNotFoundError, fmt"Path not found {errMsg}")

    if res.code != Http200:
        return (res.body, true)
    return (res.body, false)

proc singleLine*(this: string): string =
    ## Takes a multi-line string collapses it
    var toks: seq[string]

    for tok in this.split("\n"):
        toks.add(tok.strip())

    result = toks.join(" ")

proc isEmpty*(this: string): bool = 
    ## Returns `true` if a string is empty, `false` otherwise
    ##
    if this.len == 0:
        return true
    return false

proc stringifyVaultErrors*(errJson: JsonNode): string =
    if "errors" in errJson and errJson["errors"].len > 0:
        var errs: string
        for err in errJson["errors"]:
            if not errs.isEmpty:
                errs = fmt"{errs};"
            errs = fmt"{errs} {err}"
        return errs
    return ""

proc hasError*(this: JsonWithErrorIndicator): bool = 
    ## Determines if a JSON structures has an error attached
    ## 
    ##
    return if this[1]: true else: false

proc hasError*(this: StrWithErrorIndicator): bool = 
    ## Determines if a JSON structures has an error attached
    ## 
    ##
    return if this[1]: true else: false