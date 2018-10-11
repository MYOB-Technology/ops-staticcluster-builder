#!/usr/bin/env bash

read -d '' -r payload <<!
{
  "id": "c025a6f6-346d-4278-a41e-f6021f311da5",
  "url": "https://api.buildkite.com/v2/organizations/myob/pipelines/ops-staticcluster-builder",
  "web_url": "https://buildkite.com/myob/ops-staticcluster-builder",
  "name": "ops-staticcluster-builder",
  "description": null,
  "slug": "ops-staticcluster-builder",
  "repository": "git@github.com:songGithub/ops-staticcluster-builder",
  "branch_configuration": null,
  "default_branch": "master",
  "skip_queued_branch_builds": false,
  "skip_queued_branch_builds_filter": null,
  "cancel_running_branch_builds": false,
  "cancel_running_branch_builds_filter": null,
  "provider": {
    "id": "github",
    "settings": {
      "publish_commit_status": true,
      "build_pull_requests": true,
      "build_pull_request_forks": true,
      "skip_pull_request_builds_for_existing_commits": true,
      "build_tags": true,
      "publish_commit_status_per_step": false,
      "trigger_mode": "code",
      "repository": "songGithub/ops-staticcluster-builder"
    },
    "webhook_url": "https://webhook.buildkite.com/deliver/905dc52f68d86094c41a231f0df0a4872c1a0a6599277826ac"
  },
  "builds_url": "https://api.buildkite.com/v2/organizations/myob/pipelines/ops-staticcluster-builder/builds",
  "badge_url": "https://badge.buildkite.com/9d0828474b3de601925ad330356dfff8ddc0c1937c3cd1cc44.svg",
  "created_at": "2018-04-20T11:34:48.874Z",
  "env": {
    "AWS_DEFAULT_REGION": "ap-southeast-2",
    "KOPS_STATE_STORE": "s3://myob-ex-central-development-kops"
  },
  "scheduled_builds_count": 0,
  "running_builds_count": 0,
  "scheduled_jobs_count": 0,
  "running_jobs_count": 1,
  "waiting_jobs_count": 0,
  "steps": [
    {
      "type": "script",
      "name": ":nail_care: upload pipeline",
      "command": "buildkite-agent pipeline upload",
      "artifact_paths": "",
      "branch_configuration": "",
      "env": {
        "fqClusterName": "dev-green.platform.foo-dev.com",
        "KOPS_STATE_STORE": "s3://myob-ex-central-development-kops"
      },
      "timeout_in_minutes": null,
      "agent_query_rules": [
        "queue=central-dev"
      ],
      "concurrency": null,
      "parallelism": null
    }
  ]
}
!
curl -H "Authorization: Bearer $bkauth" -X PATCH -d "$payload" "https://api.buildkite.com/v2/organizations/songGithub/pipelines/ops-staticcluster-builder"
