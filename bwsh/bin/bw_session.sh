#!/usr/bin/env bash

### A dual-natured script for creating a bitwarden session.
### If sourced, logs into bitwarden with your credentials script
### BW_CREDS and exports a BW_SESSION variable. If run directly,
### it prints the BW_SESSION to stdout, instead.
###
### Usage:
###   <Options> ./bw_session.sh
###   . ./bw_session.sh
###
### Options:
###   BW_CREDS: path to the credentials script (default: "${HOME}/.secrets/bitwarden/creds.sh)
###   FORCE: force login and creating a new session
###   GET_PATH: if set to anything, print the path to the script so that it can be
###     sourced, then exit
###
### Examples:
###   # Login and print out the BW_SESSION variable
###   ./bw_session.sh
###
###   # Activate a bitwarden session
###   . ./bw_session.sh
###
###   # Source the script from wherever it is located
###   . "$(GET_PATH=1 bw_session.sh)"
###
###   # Force a new session
###   FORCE=1 bw_session.sh
###
### Remarks:
###   This script requires jq. Moreover, the BW_CREDS script must print out the credentials as json
###   in the following format:
###   {
###     "username": "foo@gmail.com",
###     "password": "mypass123"
###   }
###
###   As mentioned above, this script is dual-natured in that it can either be sourced
###   or invoked directly. In both cases, an attempt is made to log in with BW_CREDS. If the login
###   attempt is successful, the session value is either printed to stdout (when invoked directly)
###   or set on the exported BW_SESSION environment variable (when sourced).
###
###   The script also attempts to only make the appropriate calls depending on the status of the vault.
###   If the unauthenticated, a login attempt is made. If authenticated but the vault is locked,
###   the vault will be unlocked. If authenticated and the vault is unlocked, the script will unlock
###   the vault if BW_SESSION is not set.

function bw_creds {
  local bw_creds="${BW_CREDS:-"${HOME}/.secrets/bitwarden/creds.sh"}"
  if [[ ! -x "${bw_creds}" ]]; then
    log "missing executable BW_CREDS script"
    return 1
  fi

  "${bw_creds}"
}

function bw_login {
  local login_output
  if ! login_output="$(bw login --passwordfile <(get_password) "$(get_username)")"; then
    log "login failed"
    return 1
  fi

  parse_session "${login_output}"
}

function bw_unlock {
  local unlock_output
  if ! unlock_output="$(bw unlock --passwordfile <(get_password))"; then
    log "unlock failed"
    return 1
  fi

  parse_session "${unlock_output}"
}

function create_session {
  local should_export="$1"
  local vault_status
  vault_status="$(bw status | jq -r '.status')"

  local bw_session
  case "${vault_status}" in
    locked)
      log "vault is locked; unlocking"
      export_or_echo_session 'bw_unlock' "${should_export}"
      ;;
    unauthenticated)
      log "not logged in; authenticating"
      export_or_echo_session 'bw_login' "${should_export}"
      ;;
    unlocked)
      log "vault is unlocked; unlocking if BW_SESSION is not set"
      if [[ -v BW_SESSION ]]; then
        if [[ -n "${should_export}" ]]; then
          return
        fi

        echo -n "${BW_SESSION}"

        return
      fi

      export_or_echo_session 'bw_unlock' "${should_export}"
      ;;
    *)
      log "invalid vault_status [${vault_status}]"
      return 1
  esac
}

function export_or_echo_session {
  local callback="$1"
  local should_export="$2"
  if bw_session="$("${callback}")"; then
    log "created session"
    if [[ -n "${should_export}" ]]; then
      export BW_SESSION="${bw_session}"
      return
    fi

    echo -n "${bw_session}"

    return
  fi
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

function parse_session {
  echo -n "$1" \
    | grep --extended-regexp '^\$ export' \
    | sed --regexp-extended 's/^\$ export BW_SESSION="(.+)"$/\1/g'
}

function main {
  set -eo pipefail
  if [[ -v GET_PATH ]]; then
    readlink --canonicalize "$0"
    return
  fi

  create_session
}

if [[ -v FORCE ]]; then
  unset BW_SESSION
  bw logout
fi

if (return 0 &>/dev/null); then
  create_session 1
else
  main
fi
