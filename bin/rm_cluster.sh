#!/usr/bin/env bash

source bin/utils.sh
get_fqClusterName "$1"

KOPS_STATE_STORE=${2:-$KOPS_STATE_STORE}

die() { printf '%s\n' "$*" >&2; exit 1; }


# main
cd songGithub-clusters || die "directory containing code not exist! "
bin/rmCluster "$fqClusterName" yes
"$dcr"\
  -e KOPS_STATE_STORE="$KOPS_STATE_STORE"\
  kops delete -f ./clusters/.generated/cluster.yml\
  --yes 2>/dev/null
echo "cluster removal done..."
