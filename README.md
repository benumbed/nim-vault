# nim-vault
[![Travis CI](https://travis-ci.org/benumbed/rapid-rest.svg?branch=master)](https://travis-ci.org/benumbed/rapid-rest)

Light wrapper around the [HashiCorp](https://hashicorp.com/) [Vault](https://www.vaultproject.io) API.  The library is currently tested against the latest version of the [official Vault Docker container](https://hub.docker.com/_/vault).

**NOTE**: This library is a work in-progress, the supported endpoints are expanding regularly. Any Enterprise-level API calls will be provided as procs, but these procs will not be tested due to not having an Enterprise licensed server to test against.

## Documentation
Currently you'll need to take a look at the modules in `nim_vault/src/nim_vault/bare`.  Generated docs from the source are coming *Real Soon Now* (TM).


## Tests
The tests for nim-vault depend on a Vault instance running locally on port 8200 (non-TLS).  However they also support reading the `VAULT_ADDR` environment variable, and will default to that if it is set.  If the test suite fails miserably, reset that variable, or on a *NIX, prepend a `VAULT_ADDR='<your vault host here>'` to your test command.

**DO NOT USE A PRODUCTION VAULT INSTANCE TO RUN TESTS**
This cannot be stressed enough, this test suite exercises the Vault crypto API and as a result generates actual, live secrets.  Run a dev Vault instance in Docker, it's super easy! (`docker run -p 8200:8200 vault`)