## 
## Provides an interface to the `pki/` API endpoint for Vault
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import httpclient
import json

import ./connection
import ./errors

# proc pkiSign*(csr: string, common_name: string, alt_names: string, other_sans: string): json.JsonNode =
