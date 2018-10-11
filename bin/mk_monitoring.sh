#!/usr/bin/env bash

source bin/utils.sh
get_fqClusterName "$1"
export_config "$fqClusterName"


# main
cd songGithub-monitoring || die "can't cd into the dir"
bin/mkMonitoring "$fqClusterName"
