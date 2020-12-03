## 
## Utilities for token-based auth
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import os
import strformat
import nim_vault/utils
import nim_vault/types

proc findVaultToken*(tokenFileName=".vault-token", appName=""): StrWithErrorIndicator =
    ## Searches in standard locations for a vault token, returns it if it is found
    ## 
    ##
    # Check the environment first
    let env_tok = os.getEnv("VAULT_TOKEN", "")
    if not env_tok.isEmpty:
        return (env_tok, false);

    # Now check the filesystem
    var tokenFile = ""
    if not appName.isEmpty:
        tokenFile = fmt"{getConfigDir()}/{appName}/{tokenFileName}"
    else:
        tokenFile = fmt"{getHomeDir()}/{tokenFileName}"
    
    if existsFile(tokenFile):
        return (open(tokenFile).readAll, false)

    return ("", false)