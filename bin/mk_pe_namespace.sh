#!/usr/bin/env bash
source bin/utils.sh
get_fqClusterName "$1"
shortClusterName=${fqClusterName%%.*}
ns="platform-enablement"
dcr="docker-compose run --rm"
export_config "$fqClusterName"

get_vo_api_key() {
  vo_api_key="please set me!"
  input_key="$1"
  ssm_object_path="$2"
  if [ -z "$input_key" ]
  then
    vo_api_key=$(aws ssm get-parameters --names "$ssm_object_path" --with-decryption | jq -r '.Parameters[]| .Value')
    if [ -z "$vo_api_key" ]
    then
      die "can't find a secret at $ssm_object_path from your AWS account's Parameter Store"
    fi
  else
    vo_api_key="$1"
  fi
}

get_slack_api_url() {
  slack_api_url="please set me!"
  ssm_object_path="$1"

  slack_api_url="https://"$(aws ssm get-parameters --names "$ssm_object_path" --with-decryption | jq -r '.Parameters[]| .Value')
  if [ -z "$slack_api_url" ]
  then
    die "can't find a secret at $ssm_object_path from your AWS account's Parameter Store"
  fi

}

check_secret() {
  secret_name="$1"
  local_ns="$2"
  $dcr kubectl -n "$local_ns" get secret "$secret_name"
}

gen_secrets() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: gen_secrets <namespace> <slug> optional:<vo_api_key>"
    exit 1
  fi
  ns="$1"
  ns_shadow="$1-shadow"
  slug=$2
  get_vo_api_key "$3" "/k8s/clusters/vo_api_key"
  get_slack_api_url "/k8s/clusters/slack_api_url"

  grafana_pw=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 14 | head -n 1)

  echo "upsert secret - alertmgr"
  create_cmd="$dcr kubectl -n $ns_shadow create secret generic $slug-alertmanager-secret\
    --from-literal=VICTOROPS_API_KEY=$vo_api_key\
    --from-literal=SLACK_API_URL=$slack_api_url || true"
  check_secret "$slug-alertmanager-secret" "$ns_shadow"
  resp="$?"
  if [ "$resp" -eq 0 ]
  then
    echo "secret exists, update it"
    $dcr kubectl -n "$ns_shadow" delete secret "$slug-alertmanager-secret"
  else
    echo "secret not found, create one"
  fi
  $create_cmd

  echo "upsert secret - grafana"
  create_cmd="$dcr kubectl -n $ns_shadow create secret generic $slug-grafana-secret\
    --from-literal=grafana-admin-password=$grafana_pw\
    --from-literal=grafana-admin-user=admin || true"
  check_secret "$slug-grafana-secret" "$ns_shadow"
  resp="$?"
  if [ "$resp" -eq 0 ]
  then
    echo "secret $slug-grafana-secret exists, update it"
    $dcr kubectl -n "$ns_shadow" delete secret "$slug-grafana-secret"
  else
    echo "secret $slug-grafana-secret not found, create one"
  fi
  $create_cmd
}


## main
cd songGithub-namespace || die "can't cd into the dir"
bin/gen_ns "$shortClusterName" "$ns" "001-initial-setup"
gen_secrets "$ns" "pe"
bin/validate "$shortClusterName" "$ns"
bin/deploy "$shortClusterName" "$ns"
