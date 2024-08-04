## connection.nim
##
## Manages connections to Vault
##
## Author: Nick Whalen <purplxed@purplxed.dev>
## (Copyright (c) 2024 Nick Whalen. All Rights Reserved.)
##
import chronicles

import std/net
import std/ssl_config
import std/strformat 
import std/httpclient
import std/files
import std/paths
import std/envvars
import std/json
import std/strutils
import std/uri

const VAULT_API_VERSION = "v1"

type 
  VaultConnection* = object of RootObj
    url*: Uri
    token: string
    client: HttpClient

  VaultError* = object of CatchableError 
  Kv2NotFoundError* = object of VaultError


const VAULT_TOKEN_FILE: Path = expandTilde(Path("~/.vault-token"))

proc newVaultConnection*(hostname: string = "", port: int = 8200, token: string = "", tlsCtx: SslContext = newContext()): VaultConnection =
  ## Creates a new VaultConnection object and returns it. If `hostname` is not provided, this method will attempt
  ## to read the `VAULT_TOKEN` environment variable to determine the Vault url
  ## **Note:** This requires the Vault server to be available via HTTPS

  result.client = newHttpClient("nim-vault", sslContext = tlsCtx)
  result.url = (if hostname.isEmptyOrWhitespace: fmt"""{getEnv("VAULT_ADDR")}/v1""" else: fmt"https://{hostname}:{port}/{VAULT_API_VERSION}").parseUri

  info("Initializing Vault connection", url=result.url)
  
  if token.isEmptyOrWhitespace():
    if fileExists(VAULT_TOKEN_FILE):
      result.token = readFile(string(VAULT_TOKEN_FILE))
    elif existsEnv("VAULT_TOKEN"):
      result.token = getEnv("VAULT_TOKEN")
    else:
      raise newException(VaultError, "Failed to locate a Vault token")

  result.client.headers["X-Vault-Token"] = result.token

  # Check that the Vault token is actually valid
  let res = result.client.post(fmt"{result.url}/sys/capabilities-self", $(%*{"paths": ["sys/capabilities-self"]}))

  if res.code() == Http200:
    return result

  let body = res.body.parseJson
  if "errors" in body:
    raise newException(VaultError, $body["errors"])

  raise newException(VaultError, fmt"Unexpected error while talking to Vault ({result.url}): {res.body()}")

proc newMtlsVaultConnection*(key: string|Path, certificate: string|Path, caFile: string|Path = "", hostname = "", port = 8200): VaultConnection =
  ## Establishes a new mTLS connection to Vault. Note that this proc does not provide the `token` parameter since it 
  ## is expected that certificate auth will be used
  ##
  let ctx: SslContext = net.newContext(
    verifyMode = CVerifyPeerUseEnvVars, 
    certFile = certificate.string,
    keyFile = key.string, 
    caFile = caFile.string,
    cipherList=CiphersModern
  )
  newVaultConnection(hostname, port, tlsCtx=ctx)

proc upgradeToMtls*(vault: var VaultConnection, key: string|Path, certificate: string|Path, caFile: string|Path = "") =
  ## Upgrades the current Vault connection to an mTLS authenticated connection
  ##
  vault.client.close()
  let oldUrl = vault.url
  vault.client = newMtlsVaultConnection(key, certificate, caFile).client
  vault.url = oldUrl

proc setToken*(vault: var VaultConnection, token: string) =
  ## Sets the Vault auth token on the current connection
  ##
  if token.isEmptyOrWhitespace:
    raise newException(VaultError, "Token must not be empty")

  vault.token = token

proc get*(vault: VaultConnection, path: string, params: openArray[(string, string)] = @[], kv2 = false): JsonNode =
  ## Wrapper around httpclient's get method to make it more Vault-friendly
  ##
  var uri = fmt"{vault.url}{path}".parseUri
  uri.query = params.encodeQuery

  let res = vault.client.get(url = uri)
  case res.code:
    of Http200, Http201:
      result = if kv2: res.body.parseJson["data"]["data"] else: res.body.parseJson["data"]
    of Http204:
      return
    of Http404:
      raise newException(Kv2NotFoundError, $uri)
    else:
      raise newException(VaultError, fmt"Unexpected error while fetching data from Vault ({vault.url}): {res.bodyStream.parseJson}")

proc post*(vault: VaultConnection, path: string, body: JsonNode, kv2 = false): JsonNode =
  ## Wrapper around httpclient's post method
  ##
  var uri = fmt"{vault.url}{path}".parseUri

  let res = vault.client.post(url = uri, $body)
  case res.code:
    of Http200, Http201:
      result = if kv2: res.body.parseJson["data"]["data"] else: res.body.parseJson["data"]
    of Http204:
      return
    of Http404:
      raise newException(Kv2NotFoundError, $uri)
    else:
      raise newException(VaultError, fmt"Unexpected error while saving data to Vault ({vault.url}): {res.bodyStream.parseJson}")

