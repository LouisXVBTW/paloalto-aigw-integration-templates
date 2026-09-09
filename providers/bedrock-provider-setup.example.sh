#!/usr/bin/env bash
###############################################################################
# bedrock-provider-setup.example.sh
#
# Creates the AWS-side credential the AIGW needs to reach Amazon Bedrock, for the
# default "AWS Access Key" auth type:
#   1. creates an IAM user
#   2. attaches a bedrock-invoke inline policy
#   3. creates an access key (Access Key ID + Secret Access Key)
#
# Prereqs: `aws` CLI configured with rights to create IAM users/policies/access keys.
#
# Usage:
#   ./bedrock-provider-setup.example.sh
#   IAM_USER=aigw-bedrock AWS_REGION=us-east-1 ./bedrock-provider-setup.example.sh
###############################################################################
set -euo pipefail

IAM_USER="${IAM_USER:-aigw-bedrock}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "[1/3] Creating IAM user ${IAM_USER}…"
aws iam create-user --user-name "${IAM_USER}" 2>/dev/null \
  || echo "    (already exists — continuing)"

echo "[2/3] Attaching bedrock-invoke inline policy…"
aws iam put-user-policy --user-name "${IAM_USER}" --policy-name bedrock-invoke \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream"
      ],
      "Resource": "*"
    }]
  }'

echo "[3/3] Creating an access key…"
echo "      Copy the two values below — the Secret Access Key is shown only once."
aws iam create-access-key --user-name "${IAM_USER}" \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text

cat <<EOF

Done.
  IAM user   : ${IAM_USER}
  Policy     : bedrock-invoke (InvokeModel / Converse)
  Access key : the AccessKeyId + SecretAccessKey printed above — copy now, never commit.

Next:
  - Enable model access: Amazon Bedrock console → Model access → enable the models
    you want (otherwise calls 403 with aws-marketplace:Subscribe; allow a few
    minutes to propagate).
  - In the AIGW: add an Amazon Bedrock integration, AWS Auth Type = AWS Access Key,
    paste the Access Key Id + Secret Access Key, Region = ${AWS_REGION}.
EOF
