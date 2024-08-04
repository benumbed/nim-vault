## 
## Provides an interface to the `pki/` API endpoint for Vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json
import strformat

import ../connection
import ../../utils
import ../../types
import ../../errors


proc pkiReadCaCertificate*(this: VaultConnection, asPem: bool = false, mountpoint: string = "/pki"): 
                          StrWithErrorIndicator =
    ## Retrieves the CA certificate for the given pki mountpoint
    ## https://www.vaultproject.io/api-docs/secret/pki#read-ca-certificate
    ##
    return expectHttp200Raw(this.client.get(this.api_path(if asPem: fmt"{mountpoint}/ca/pem" else: fmt"{mountpoint}/ca")))

proc pkiReadCaCertificateChain*(this: VaultConnection, mountpoint: string = "/pki"): StrWithErrorIndicator =
    ## Retrieves the CA certificate chain in PEM format
    ## https://www.vaultproject.io/api-docs/secret/pki#read-ca-certificate-chain
    ##
    let resp = this.client.get(this.api_path(fmt"{mountpoint}/ca_chain"))

    # Vault will return an HTTP 204 if there's no chain loaded
    if resp.code == Http204:
        return ("", false)

    return expectHttp200Raw(resp)

proc pkiReadCertificate*(this: VaultConnection, serial: string, mountpoint: string = "/pki"): StrWithErrorIndicator =
    ## Retrieves a specific certificate from Vault via its serial (PEM format)
    ## https://www.vaultproject.io/api-docs/secret/pki#read-certificate
    ##
    return expectHttp200Raw(this.client.get(this.api_path(fmt"{mountpoint}/cert/{serial}")))


proc pkiListCertificates*(this: VaultConnection, mountpoint: string = "/pki"): JsonWithErrorIndicator =
    ## Lists all certificates' serials in Vault
    ## https://www.vaultproject.io/api-docs/secret/pki#list-certificates
    ##
    return expectHttp200(this.client.list(this.api_path(fmt"{mountpoint}/certs")))

proc pkiRotateCrls*(this: VaultConnection, mountpoint: string = "/pki"): JsonWithErrorIndicator =
    ## Rotates the CRL of the CA
    ## https://www.vaultproject.io/api-docs/secret/pki#rotate-crls
    ## 
    return expectHttp200(this.client.get(this.api_path(fmt"{mountpoint}/crl/rotate")))

proc pkiGenerate*(this: VaultConnection, role_name: string, common_name: string, alt_names: string = ""
                 , ip_sans: string = "", uri_sans: string = "", other_sans: string = "", ttl: string = ""
                 , format: string = "pem", private_key_format: string = "der", exclude_cn_from_sans: bool = false
                 , mountpoint: string = "/pki"): JsonWithErrorIndicator =
    ## Generates a new key/cert pair for the provided common_name within the provided role
    ## https://www.vaultproject.io/api-docs/secret/pki#generate-certificate
    ## 
    let callBody = %*{
        "common_name": common_name,
        "alt_names": alt_names,
        "ip_sans": ip_sans,
        "uri_sans": uri_sans,
        "other_sans": other_sans,
        "format": format,
        "private_key_format": private_key_format,
        "exclude_cn_from_sans": exclude_cn_from_sans
    }

    if not ttl.isEmpty:
        callBody.add("ttl", newJString(ttl))
    
    return expectHttp200(this.client.post(this.api_path(fmt"{mountpoint}/issue/{role_name}"), body = $callBody))

proc pkiSignCertificate*(this: VaultConnection, role_name: string, csr: string, common_name: string
                 , alt_names: string = "", other_sans: string = "", ip_sans: string = "", uri_sans: string = ""
                 , ttl: string = "", format: string = "pem" , exclude_cn_from_sans: bool = false
                 , mountpoint: string = "/pki"): JsonWithErrorIndicator =
    ## Generates a new key/cert pair for the provided common_name within the provided role
    ## https://www.vaultproject.io/api-docs/secret/pki#generate-certificate
    ## 
    let callBody = %*{
        "common_name": common_name,
        "alt_names": alt_names,
        "ip_sans": ip_sans,
        "uri_sans": uri_sans,
        "other_sans": other_sans,
        "format": format,
        "exclude_cn_from_sans": exclude_cn_from_sans
    }

    if not ttl.isEmpty:
        callBody.add("ttl", newJString(ttl))
    
    return expectHttp200(this.client.post(this.api_path(fmt"{mountpoint}/sign/{role_name}"), body = $callBody))