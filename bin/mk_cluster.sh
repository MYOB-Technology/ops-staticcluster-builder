#!/usr/bin/env bash

check_cluster_exist() {
  dcr="docker-compose run --rm"
  fqClusterName="$1"
  $dcr -e KOPS_STATE_STORE="$KOPS_STATE_STORE" kops get cluster "$fqClusterName" 1>/dev/null
  rc="$?"
  if [ ! "$rc" -eq 0 ]; then
    echo "false"
  else
    echo "true"
  fi
}

generate_kops_secret() {
  echo "creating secret kops-$1"
  if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
  fi

  if [ -f ~/.ssh/kops-"$1" ]; then
    rm ~/.ssh/kops-"$1"
  fi

  ssh-keygen -t rsa -b 2048 -f ~/.ssh/kops-"$1" -q -N ""
  echo "secret generated..."
}

# ensure users authenticated to group `kubernetes-<cluster-short-name>-*` have
# cluster admin permission
promote_to_cluster_admin_role() {
  fqClusterName="$1"
  shortClusterName=${fqClusterName%%.*}
  docker-compose down
  docker-compose pull kubectl
  kubectl="docker-compose run --rm kubectl"
  # create a c-role-bindings that points to cluster-admin role.
  $kubectl apply -f - << EOF
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-$shortClusterName-staticcluster-operator
subjects:
- kind: Group
  name: kubernetes-$shortClusterName-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
}


# main
source bin/utils.sh
get_fqClusterName "$1"

cd songGithub-clusters || die "can't cd into the dir"
if [ "$(check_cluster_exist "$fqClusterName")" != "true" ]; then
  echo "not exist yet, creating one..."
  generate_kops_secret dev
  bin/mkCluster "$fqClusterName"
else
  echo "The cluster ""$fqClusterName"" already exist!, let's update it!"
  bin/mkCluster "$fqClusterName" --update
fi

# to solve this JIRA ticket https://arlive.atlassian.net/browse/PET-633
promote_to_cluster_admin_role "$fqClusterName"
