#!/usr/bin/env bash

set -eo pipefail

### Reset an item's password.
###
### Usage:
###   reset_password.sh <Arguments>
###
### Arguments:
###   cred_name: name of the item to reset; is treated as a search
###     pattern by default, per bitwarden-cli's behavior, unless
###     EXACT_MATCH is set, in which case the item with the name
###     as exactly typed is filtered for
###
### Examples:
###   # reset the password of any item with anything that
###   # that matches the pattern ally
###   reset_password.sh ally
###
###   # reset the password of any item with anything whose name
###   # exactly matches the word ally
###   EXACT_MATCH=1 reset_password.sh ally
###
### Remarks:
###   This command is a pass-through to bitwarden CLI and uses jq
###   to manipulate the items.

function log {
  >&2 printf '[%s] %s\n' "$(date)" "$1"
}

function main {
  local cred_name="$1"
  echo "${cred_name}"

  local json
  if [[ -n "${EXACT_MATCH}" ]]; then
    log "looking up details of credential matching pattern ${cred_name}"
    bw get item "${cred_name}" 2>&1 \
      | grep -iv more \
      | xargs -I {} bw get item {} \
      | jq \
          --slurp \
          --raw-output \
          --arg cred_name "${cred_name}" \
          '.[] | select(.name == $cred_name)'
  else
    log "looking up details of credential matching word ${cred_name}"
    json="$(bw get item "${cred_name}")"
  fi

  if [[ -z "${json}" ]]; then
    log "could not find details for ${cred_name}"
    return 1
  fi

  log "generating new password"

  local new_pass
  new_pass="$(bw generate password --uppercase --lowercase --special --number 20)"

  local item_id
  item_id="$(jq -r .id <<<"${json}")"

  log "setting new password"
  jq ".login.password=\"${new_pass}\"" <<<"${json}" \
    | base64 \
    | bw edit item "${item_id}" > /dev/null 2>&1
  log "done"
}

main "$1"
