#!/usr/bin/env bash

set -eo pipefail

### Rename an item.
###
### Usage:
###   rename_item.sh <Arguments>
###
### Arguments:
###   old_item_name: the name of the item to be renamed
###   new_item_name: the new name of the item
###
### Examples:
###   # rename item foo to bar
###   rename_item.sh foo bar
###
### Remarks:
###   This command is a pass-through to bitwarden CLI and uses jq
###   to manipulate the items.

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"
readonly ROOT_DIR

function log {
  >&2 printf '[%s] %s\n' "$(date --iso=s)" "$1"
}

function main {
  # shellcheck disable=SC1090
  . "${ROOT_DIR}/bw_session.sh"

  local old_item_name="$1"
  local new_item_name="$2"

  local item_json
  if ! item_json="$(bw get item "${old_item_name}")"; then
    log "failed to retrieve item"
    return 1
  fi

  local item_id
  item_id="$(jq -r '.id' <<<"${item_json}")"
  jq ".name=\"${new_item_name}\"" <<<"${item_json}" \
    | base64 -w 0 \
    | bw edit item "${item_id}"
}

main "$@"
