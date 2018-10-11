# The Static Cluster Builder

It builds a k8s cluster with KOPS, installs k8s system and monitoring components, creates a namespace. Then at the end, it allows users to tear down the Cluster properly with a push button.

The project fully automates our k8s cluster creation process. Therefore, it documents all necessary steps to build a Cluster with code, and eliminates knowledge hidden by previously manual install operations.

## Get started

- To create a pipeline, please run `./bin/mkpipe.sh dflt ops-staticcluster-builder <a-bk-pipeline-name>`
- To create a build/static cluster, please go to the pipeline, create a new build. Enter following:
  * In Message, type in any message for the build. Note it is compulsory.

## Env Var required for the Pipeline

- (individual build) fqClusterName: "dev-red/green.platform.songGithubdev.com"
- (preset for pipeline) AWS_DEFAULT_REGION: "ap-southeast-2"
- (preset for pipeline) KOPS_STATE_STORE: "s3://songGithub-ex-central-development-kops"

## Secret required in AWS Parameter Store

- Github personal token
  * for downloading code from private Github repositories (Read access required)
  * for installing Deploy Keys for this Repo (Admin access required)
- secret for a namespace: Slack api url
- secret for a namespace: Victor Ops routing key


### set Github personal token

This token should belong to a Github user that has Admin permission on this Repo.
- `aws ssm put-parameter --name /ops/bk/replicant-github-api-token --value 12345 --type SecureString --overwrite`


### set slack api url

- `aws ssm put-parameter --name /k8s/clusters/slack_api_url --description "slack api url required by alertmanager module to work" --value "hooks.slack.com/services/12345"  --type SecureString --overwrite`


### set Victor Ops routing key

- `aws ssm put-parameter --name /k8s/clusters/vo_api_key --description "the victor ops api key for platform-enablement" --value "abcdef"  --type SecureString --overwrite`
