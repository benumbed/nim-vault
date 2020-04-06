## 
## Helpful utilities
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strutils

proc singleLine*(this: string): string =
    ## Takes a multi-line string collapses it
    var toks: seq[string]

    for tok in this.split("\n"):
        toks.add(tok.strip())

    result = toks.join(" ")
