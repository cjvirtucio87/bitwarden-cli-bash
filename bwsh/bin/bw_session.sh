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
###   attempt is successful, the session value is captured from bw's output and cached in a file.
###   This session value is then set to BW_SESSION and exported, so that future bw calls can
###   be made without having to log in again.

function bw_creds {
  local bw_creds="${BW_CREDS:-"${HOME}/.secrets/bitwarden/creds.sh"}"
  if [[ ! -x "${bw_creds}" ]]; then
    log "missing executable BW_CREDS script"
    return 1
  fi

  "${bw_creds}"
}

function bw_login {
  local session_file="${HOME}/.secrets/bitwarden/session"
  if [[ -v FORCE ]]; then
    rm -f "${session_file}"
    bw logout
  fi

  if bw login --check "$(get_username)" &>/dev/null; then
    log "already logged in"
    if [[ -f "${session_file}" ]]; then
      cat "${session_file}"
      return
    fi

    log "missing session file; logout and log back in with this script"
    return 1
  fi

  local login_output
  if ! login_output="$(bw login --passwordfile <(get_password) "$(get_username)")"; then
    log "login failed"
    return 1
  fi

  mkdir --parents "${HOME}/.secrets/bitwarden"
  echo -n "${login_output}" \
    | grep --extended-regexp '^\$ export' \
    | sed --regexp-extended 's/^\$ export BW_SESSION="(.+)"$/\1/g' \
    | tee "${session_file}"
  chmod 0600 "${session_file}" &>/dev/null
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
  if [[ -v GET_PATH ]]; then
    readlink --canonicalize "$0"
    return
  fi

  bw_login
}

if (return 0 &>/dev/null); then
  if [[ -v BW_SESSION ]]; then
    log "already logged in"
  elif [[ -f "${HOME}/.secrets/bitwarden/session" ]]; then
    log "detected cached session file"
    BW_SESSION="$(cat "${HOME}/.secrets/bitwarden/session")"
    export BW_SESSION
  elif bw_session="$(bw_login)"; then
    log "logged in"
    export BW_SESSION="${bw_session}"
  else
    log "login failed"
    return 1
  fi
else
  main
fi
