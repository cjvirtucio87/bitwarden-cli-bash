#!/usr/bin/env bash

set -e

### Script for creating and uploading releases.
###
### Usage:
###   ./release.sh
###
### Options:
###   DEBUG:
###     If set to anything, enables debug mode.
###
###   FULL_RELEASE:
###     If set to anything, makes the release a full release.

ROOT_DIR="$(dirname "$0" | tr -d '\n')"
readonly ROOT_DIR

function cleanup {
  >&2 echo "begin cleanup"
  if [[ -d "${TEMP_DIR}" ]]; then
    >&2 echo "purging TEMP_DIR [${TEMP_DIR}]"
    rm -rf "${TEMP_DIR}"
  fi
  >&2 echo "end cleanup"
}

function create_release {
  local api_release_url="$1"
  local github_api_token="$2"
  local release_json="$3"

  >&2 echo "creating release"
  curl \
    --data "${release_json}" \
    -H "Authorization: token ${github_api_token}" \
    "${api_release_url}"
}

function upload_release_asset {
  local uploads_release_url="$1"
  local github_api_token="$2"
  local release_id="$3"
  local release_dir="$4"
  local asset_name="$5"

  >&2 echo 'uploading release asset'
  tar \
      --gunzip \
      --create \
      --verbose \
      --to-stdout \
      --directory "${release_dir}" \
      --exclude '.git' \
      --exclude '*.swo' \
      --exclude '*.swp' \
      . \
      | curl \
        -X POST \
        -H "Authorization: token ${github_api_token}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary '@-' \
        "${uploads_release_url}/${release_id}/assets?name=${asset_name}"
}

function main {
  echo "starting release"

  TEMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  local version
  version="$(gitversion)"
  >&2 echo "releasing version: ${version}"

  local release_yaml
  release_yaml="${TEMP_DIR}/release.yml"
  touch "${release_yaml}"
  clconf --ignore-env --yaml "${release_yaml}" setv 'tag_name' "bitwarden-cli-bash-${version}"
  clconf --ignore-env --yaml "${release_yaml}" setv 'target_commitish' 'master'
  clconf --ignore-env --yaml "${release_yaml}" setv 'name' "bitwarden-cli-bash-${version}"
  clconf --ignore-env --yaml "${release_yaml}" setv 'body' "bitwarden-cli-bash release, version ${version}"
  clconf --ignore-env --yaml "${release_yaml}" setv 'draft' 'false'

  if [[ -z "${FULL_RELEASE}" ]]; then
    clconf --ignore-env --yaml "${release_yaml}" setv 'prerelease' 'true'
  fi

  if [[ ! -f "${ROOT_DIR}/secrets.override.yml" ]]; then
    >&2 echo "missing secrets.override.yml"
    return 1
  fi

  local clconf_args=(
    --yaml "${ROOT_DIR}/secrets.yml"
    --yaml "${ROOT_DIR}/secrets.override.yml"
  )
  local release_json
  release_json="$(clconf --yaml "${release_yaml}" --ignore-env getv --as-json --pretty | sed -E 's,"(false|true)",\1,g')"

  local release_response
  release_response="$(create_release \
    "$(clconf getv "${clconf_args[@]}" 'api_release_url')" \
    "$(clconf getv "${clconf_args[@]}" 'github_api_token')" \
    "${release_json}")"

  local release_id
  if ! release_id="$(clconf --yaml <(echo "${release_response}") --ignore-env getv 'id')"; then
    >&2 echo "failed to retrieve release ID"
    >&2 echo "${release_response}"
    return 1
  fi

  local asset_name
  asset_name="cjvirtucio87-bitwarden-cli-bash-${version}.tar.gz"

  local upload_release_asset_response
  upload_release_asset_response="$(upload_release_asset \
    "$(clconf "${clconf_args[@]}" getv 'uploads_release_url')" \
    "$(clconf "${clconf_args[@]}" getv 'github_api_token')" \
    "${release_id}" \
    "${ROOT_DIR}/bwsh" \
    "${asset_name}")"

  if [[ -n "${DEBUG}" ]]; then
    >&2 clconf --yaml <(echo "${upload_release_asset_response}")
  fi
  echo "completed release"
}

main "$@"
