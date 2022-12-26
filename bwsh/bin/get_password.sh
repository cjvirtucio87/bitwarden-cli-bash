#!/usr/bin/env bash

set -eo pipefail

### Get an item's password.
###
### Usage:
###   get_password.sh <Arguments>
###
### Arguments:
###   cred_name: name of the item whose password will be retrieved; is
###     treated as a search pattern by default, per
###     bitwarden-cli's behavior, unless
###     EXACT_MATCH is set, in which case the item with the name
###     as exactly typed is filtered for
###
### Examples:
###   # get the password of any item with anything that
###   # that matches the pattern ally
###   get_password.sh ally
###
###   # get the password of any item with anything whose name
###   # exactly matches the word ally
###   EXACT_MATCH=1 get_password.sh ally
###
### Remarks:
###   This command is a pass-through to bitwarden CLI and uses jq
###   to manipulate the items.

function main {
  local cred_name="$1"
  if [[ -n "${EXACT_MATCH}" ]]; then
    log "looking up password of credential matching pattern ${cred_name}"
    bw get item "$1" 2>&1 \
      | grep -iv more \
      | xargs -I {} bw get item {} \
      | jq -r "select(.name == \"${cred_name}\") | .login.password"
  else
    log "looking up password of credential matching word ${cred_name}"
    bw get password "${cred_name}"
  fi
}

main "$1"
