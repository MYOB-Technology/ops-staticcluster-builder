#!/usr/bin/env bash

set -e

repo=$1
branch=$2

github_token=$(aws ssm get-parameters --names /ops/bk/replicant-github-api-token --with-decryption | jq -r '.Parameters[]|.Value')


is_running_on_CI() {
  if [ ! -z "$CI" ] && [ "$CI" == "true" ]; then
    echo "true"
  else
    echo "false"
  fi
}


if [ -d "$repo" ]; then
  rm -rf "$repo"
fi

if [ "$(is_running_on_CI)" == "true" ]
then

  echo "running on CI"
  if [ -z "$branch" ]
  then
    git clone https://"$github_token"@github.com/songGithub/"$repo".git
  else
    git clone -b "$branch" https://"$github_token"@github.com/songGithub/"$repo".git
  fi

elsew

  echo "not running on CI"
  if [ -z "$branch" ]
  then
    git clone git@github.com:songGithub/"$repo".git
  else
    git clone -b "$branch" git@github.com:songGithub/"$repo".git
  fi

fi
