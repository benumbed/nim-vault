## 
## Common structures for Vault API
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import json


type JsonWithErrorIndicator* = tuple[response: JsonNode, error: bool]
type StrWithError* = tuple[output: string, error: bool]