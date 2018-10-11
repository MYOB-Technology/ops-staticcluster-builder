#!/usr/bin/env bash

set -e

die() { printf '%s\n' "$*" >&2; exit 1; }

if [[ -z "${KOPS_STATE_STORE}" ]]; then
  die "KOPS_STATE_STORE must be set as an Env Var!"
else
  echo " 1/2 KOPS_STATE_STORE: ""$KOPS_STATE_STORE"
fi

if [[ -z "${AWS_DEFAULT_REGION}" ]]; then
  die "AWS_DEFAULT_REGION must be set as an Env Var!"
else
  echo " 2/2 AWS_DEFAULT_REGION: ""$AWS_DEFAULT_REGION"
fi

echo "preflight check passed"
