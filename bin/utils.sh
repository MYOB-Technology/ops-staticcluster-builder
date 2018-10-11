#!/usr/bin/env bash

export_config() {
  fqClusterName="$1"
  dcr="docker-compose run --rm"
  $dcr -e KOPS_STATE_STORE="$KOPS_STATE_STORE" kops export kubecfg "$fqClusterName"
}

is_running_on_CI() {
  if [ ! -z "$CI" ] && [ "$CI" == "true" ]; then
    echo "true"
  else
    echo "false"
  fi
}

get_fqClusterName() {
  if [ "$(is_running_on_CI)" == "true" ]; then
    # get the fqClusterName from bk agent key store
    fqClusterName=$(buildkite-agent meta-data get fqClusterName)
  else
    # get the fqClusterName from env var or arg input
    fqClusterName=${1:-$fqClusterName}
  fi
  echo "  fqClusterName = ""$fqClusterName"
}

die() { printf '%s\n' "$*" >&2; exit 1; }
