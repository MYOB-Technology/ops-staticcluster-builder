#!/usr/bin/env bash
#
# create a pipeline (keys, hooks, the lot)
RANDOM=$$$(date +%s)
queue_name="central-dev"
# base funcs
usage() { echo "usage: $0 [-write] <stack-slug> <repo-slug|repo-url> <pipeline-name> [emoji-slug]"; exit 64; }
die() {
    printf '%s\n' "$*" >&2
    [[ "$hlpmsg" == "" ]] || printf '\nPROTIP - %s\n' "$hlpmsg"
    exit 1
}
success() {
    e=("ヽ(°〇°)ﾉ" "(°ロ°) !" "(^０^)ノ" "(⌒ω⌒)ﾉ" "(∩ᄑ_ᄑ)⊃━☆ﾟ*･｡*･:≡( ε:)" "╰( ͡° ͜ʖ ͡° )つ──☆*:・ﾟ" "( ͡° ͜ʖ ͡°)" "ଘ(੭ˊᵕˋ)੭* ੈ✩‧₊˚")
    printf '\nCOMPLETE   %s\n' "${e[$RANDOM%${#e[@]}]}"
    exit 0
}


# vars
bkapi="https://api.buildkite.com/v2"
ghapi="https://api.github.com"
hlpmsg=""

[[ "$AWS_DEFAULT_REGION" == "" ]] && AWS_DEFAULT_REGION="$AWS_REGION"
[[ "$AWS_DEFAULT_REGION" == "" ]] && AWS_DEFAULT_REGION="ap-southeast-2"


# args
write=0; emoji=nail_care
[[ "$1" == "-write" ]] && { shift; write=1; }
slug="$1"; repo="$2"; pipename="$3"
[[ "$slug" == "" || "$repo" == "" || "$pipename" == "" ]] && usage
[[ "$4" == "" ]] || emoji="$4"

echo -n "initializing: "


# dep check
echo -n "deps"
deps=(basename curl aws jq ssh-keygen)
missing=()
for dep in "${deps[@]}"; do
    echo -n "."
    hash "$dep" 2>/dev/null || missing+=("$dep")
done
[[ "${#missing[@]}" -gt 0 ]] && die "missing deps: ${missing[*]}"
hlpmsg="auth failed against AWS API. check your credentials helper (songGithub-auth etc)"
aws sts get-caller-identity &>/dev/null || die " (fail) unable to connect to AWS"
hlpmsg=""
echo -n " "


# reinflate state
hlpmsg="one or more global parameters are missing from parameter store. uh oh."
echo -n "state"
bk_params=(/ops/bk/org-slug /ops/bk/repo-org /ops/bk/api-token \
    /ops/bk/replicant-github-api-token /ops/bk/queue-prefix /ops/bk/env-slug)
resp=$(aws ssm get-parameters --names "${bk_params[@]}" --with-decryption 2>/dev/null)
echo -n "."
pmissing=$(jq -r '.InvalidParameters[]' <<<"$resp" | tr $'\n' ' ')
[[ "$pmissing" == "" ]] || die " (fail) missing global params: $pmissing"
echo -n "."
while read -r pkey; read -r pval; do
    case "$pkey" in
        *org-slug)         org="$pval";;
        *repo-org)         repo_org="$pval";;
        *github-api-token) ghtoken="$pval";;
        *api-token)        bktoken="$pval";;
        *queue-prefix)     queuepfx="$pval";;
        *env-slug)         envslug="$pval";;
    esac
done < <(jq -r '.Parameters[]|.Name,.Value' <<<"$resp")
bkauth="Authorization: Bearer $bktoken"
ghauth="Authorization: token $ghtoken"
echo -n "."
hlpmsg=""
echo -n " "


# validate pipename
echo -n "arg-pipe"
echo -n "."
[[ "${#pipename}" -gt 255 ]] && die " (fail) '$pipename' > 255char"
echo -n "."
[[ "$pipename" =~ ^[-a-z0-9]+$ ]] || die " (fail) '$pipename' must match ^[-a-z0-9]+$"
echo -n " "


# validate repo url or slug
echo -n "arg-repo"
[[ "$repo" =~ github\.com ]] || repo="git@github.com:$repo_org/$repo"
re='^(https:\/\/|git@)(github\.com:|bitbucket\.com\/)'"$repo_org"'\/[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
hlpmsg="the repo-url (calculated if slug is passed in) does not match this re: $re"
[[ "$repo" =~ $re ]] || die " (fail) bad looking repo url: $repo"
echo -n "."
hlpmsg="trying to reckon the repo-slug from $repo didn't work out"
reposlug=$(basename "${repo%.git}" | tr '[:upper:]' '[:lower:]')
[[ "$reposlug" == "" ]] && die " (fail) unable to basename|tr $repo"
echo -n "."
hlpmsg=""
echo -n " "


# get list of stacks
hlpmsg="querying for deployed stacks named ^ops-bk-\\w+-agent$ failed; is it deployed?"
echo -n "stacks"
stacks=()
while read -r; do
    echo -n "."
    stacks+=("$REPLY")
done < <(aws cloudformation describe-stacks --query 'Stacks[].StackName' | jq -r '.[]' \
| grep -E '^ops-bk-\w+-agent$' | cut -d- -f3) || die " (fail) unable to query for deployed stacks"
[[ "${stacks[*]}" =~ $slug ]] || die " (fail) $slug not in list of running stacks"
hlpmsg=""; echo -n " "


# get pipeline details
bkapi_pipe="$bkapi/organizations/$org/pipelines"
echo -n "pipe-details"
{
    read -r badge
    read -r webhook
} < <(curl -fsH "$bkauth" "$bkapi_pipe/$pipename" | jq -r '.badge_url,.provider.webhook_url' 2>/dev/null)
[[ "$webhook" == "" ]] && echo -n "x"
echo ". OK"; hlpmsg=""


# generate a new ssh key - existing will be rotated
echo -n "deploy-keys: key-material"
hlpmsg="an attempt to execute tmpfile and ssh-keygen has failed. probably an OS/distro problem."
tmpfile=$(mktemp)
trap 'rm -f '"$tmpfile{,.pub}" EXIT
yes | ssh-keygen -t rsa -b 4096 -f "$tmpfile" -N '' >/dev/null
pubkey=$(<"$tmpfile.pub")
echo -n ". "

## delete deploy key(s) from github
echo -n "delete-old"
ghapi_keys="$ghapi/repos/$repo_org/$reposlug/keys"
hlpmsg="something went wrong when querying/deleting deploy keys from the github repo. token scopes? repo access?"
keytitle="buildkite-$pipename-$envslug"
resp=$(curl -fsH "$ghauth" "$ghapi_keys") \
    || die " (fail) unable to get deploy keys from github"
while read -r title; read -r id; do
    echo -n "."
    [[ "$title" != "$keytitle" ]] && continue
    curl -sH "$ghauth" -X DELETE "$ghapi_keys/$id" || die " (fail) unable to delete key $title"
done < <(jq -r '.[]|.title,.id' <<<"$resp") || die " (fail) unable to unmarshal response"
echo -n " "; hlpmsg=""

## upload new deploy key
depkey_ro="true"
[[ "$write" -gt 0 ]] && depkey_ro="false"
hlpmsg="something went wrong uploading the new deploy key to the github repo. token scopes?"
echo -n "upload"
curl -sH "$ghauth" -X POST -H "Content-Type: application/json" \
    -d '{"title":"'"$keytitle"'","read_only":'"$depkey_ro"',"key":"'"$pubkey"'"}' \
    "$ghapi_keys" >/dev/null || die " (fail) unable to upload new key material"
echo -n ". "; hlpmsg=""

## upload private material to all buckets
hlpmsg="an encrypted copy of the private key material could not be copied to a secrets bucket. could be the secrets-bucket param."
echo -n "s3-secrets"
for stack in "${stacks[@]}"; do
    echo -n "."
    buck_sec=$(aws ssm get-parameter --name "/ops/bk/$stack/secrets-bucket" --query Parameter.Value --output text 2>/dev/null)
    [[ "$buck_sec" == "" ]] && die " (fail) unable to read /ops/bk/$stack/secrets-bucket (ssm)"
    aws s3 cp --acl private --sse aws:kms "$tmpfile" "s3://songGithub-buildkite-$queue_name-secrets/$pipename/private_ssh_key" >/dev/null \
        || die " (fail) unable to upload key to $buck_sec"
done
echo " OK"; hlpmsg=""


# create pipeline
if [[ "$webhook" == "" ]]; then
    echo -n "creating pipeline: "

    echo -n "get-team"
    hlpmsg="unable to get /ops/bk/$slug/team-uuid"
    teamuuid=$(aws ssm get-parameter --name "/ops/bk/$slug/team-uuid" --query Parameter.Value --output text 2>/dev/null)
    [[ "$teamuuid" == "" ]] && die " (fail) unable to get value from ssm"

    ## construct payload
    echo -n " payload."
    read -d '' -r payload <<!
{
    "name": "$pipename",
    "repository": "$repo",
    "description": "A pipeline that manage life cycle of static k8s Cluster (dev-green, or dev-red)",
    "env": {
        "AWS_DEFAULT_REGION": "ap-southeast-2",
        "KOPS_STATE_STORE": "s3://songGithub-ex-central-development-kops"
    },
    "steps": [
        {
            "type": "script",
            "name": ":$emoji: upload pipeline",
            "command": "buildkite-agent pipeline upload",
            "agent_query_rules": ["queue=$queue_name"]
        }
    ],
    "provider_settings": {
        "publish_commit_status": true,
        "build_pull_requests": true,
        "build_pull_request_forks": true,
        "skip_pull_request_builds_for_existing_commits": true,
        "build_tags": true,
        "publish_commit_status_per_step": false,
        "trigger_mode": "code"
    },
    "team_ids": ["$teamuuid"]
}
!
    echo -n " creating."
    hlpmsg="there was a problem creating the pipeline on the BK REST API. check networky things."
    resp=$(curl -sH "$bkauth" -X POST -d "$payload" "$bkapi/organizations/$org/pipelines")
    jq -er '.|.badge_url' <<<"$resp" &>/dev/null \
        || die " (fail) unable to create pipeline: $(jq -r '.errors[].code' <<<"$resp")"
    badge=$(jq -r '.|.badge_url' <<<"$resp")
    webhook=$(jq -r '.|.provider.webhook_url' <<<"$resp")
    hlpmsg=""; echo " OK"
fi


# # ensure webhook is present
# echo -n "webhook: get-hooks"; hlpmsg=""
# ghapi_hooks="$ghapi/repos/$repo_org/$reposlug/hooks"
# hlpmsg="unable to query/add webhook to github repo. scopes maybe?"
# add_hook=1
# while read -r id; read -r whurl; do
#     echo -n "."
#     [[ "$whurl" == "$webhook" ]] && { add_hook=0; break; }
# done < <(curl -fsH "$ghauth" "$ghapi_hooks" | jq -r '.[]|.id,.config.url')
# if [[ "$add_hook" -gt 0 ]]; then
#     echo -n " add-hook"
#     payload='{"name":"web","active":true,"events":["push","pull_request","deployment"],"config":{"url":"'"$webhook"'","cotent_type":"json"}}'
#     curl -sH "$ghauth" -X POST -H "Content-Type: application/json" -d "$payload" "$ghapi_hooks" >/dev/null \
#         || die " (fail) unable to write hook"
# fi
# echo " OK"; echo; hlpmsg=""


# operation complete
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo "BADGE URL: $badge"
echo "MARKDOWN : [![Build status]($badge)](https://buildkite.com/$org/$pipename)"
echo "TIP      : add '?branch=BRANCHNAME' to the URL to filter"
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
success
