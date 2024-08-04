## 
## Errors for nim_vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
type VaultError* = object of CatchableError

type VaultNotFoundError* = object of VaultError
type VaultTokenError* = object of VaultError