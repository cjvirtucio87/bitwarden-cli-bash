#!/usr/bin/env bash

### A dual-natured script for creating a bitwarden session.
### If sourced, logs into bitwarden with your credentials script
### BW_CREDS and exports a BW_SESSION variable. If run directly,
### it prints the BW_SESSION to stdout, instead.
###
### Usage:
###   <Options> ./bw_session.sh <Arguments>
###   . ./bw_session.sh
###
### Options:
###   BW_CREDS: path to the credentials script (default: "${HOME}/.secrets/bitwarden/creds.sh)
###
### Examples:
###   # Login and print out the BW_SESSION variable
###   ./bw_session.sh
###
###   # Activate a bitwarden session
###   . ./bw_session.sh
###
### Remarks:
###   This script requires jq. Moreover, the BW_CREDS script must print out the credentials as json
###   in the following format:
###   {
###     "username": "foo@gmail.com",
###     "password": "mypass123"
###   }

function bw_creds {
  local bw_creds="${BW_CREDS:-"${HOME}/.secrets/bitwarden/creds.sh"}"
  log "BW_CREDS: ${bw_creds}"
  if [[ ! -x "${bw_creds}" ]]; then
    log "missing executable BW_CREDS script"
    return 1
  fi

  "${bw_creds}"
}

function bw_login {
  bw login \
    --passwordfile <(get_password) "$(get_username)" \
    | grep --extended-regexp '^\$ export' \
    | sed --regexp-extended 's/^\$ export BW_SESSION="(.+)"$/\1/g'
}

function get_password {
  bw_creds | jq -r '.password'
}

function get_username {
  bw_creds | jq -r '.username'
}

function log {
  >&2 printf '[%s] %s\n' "$(date --iso=s)" "$1"
}

function main {
  set -eo pipefail
  bw_login
}

if (return 0 &>/dev/null); then
  if ! BW_SESSION="$(bw_login)"; then
    log "login failed"
  else
    export BW_SESSION
  fi
else
  main "$@"
fi
