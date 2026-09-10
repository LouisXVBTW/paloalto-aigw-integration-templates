#!/usr/bin/env bash
###############################################################################
# vertex-provider-setup.example.sh
#
# Creates the GCP-side credential the AIGW needs to reach Google Vertex AI:
#   1. enables the Vertex AI API
#   2. creates a service account
#   3. grants it roles/aiplatform.user
#   4. generates a JSON key you upload to the AIGW (Auth type = Service Account File)
#
# Prereqs: `gcloud` installed + `gcloud auth login`, and rights to enable services,
# create service accounts/keys, and set IAM policy on the project.
#
# Usage:
#   PROJECT_ID=your-gcp-project ./vertex-provider-setup.example.sh
#   # optional overrides:
#   PROJECT_ID=... SA_NAME=aigw-vertex KEY_FILE=vertex-sa.json ./vertex-provider-setup.example.sh
###############################################################################
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID=your-gcp-project}"
SA_NAME="${SA_NAME:-aigw-vertex}"
KEY_FILE="${KEY_FILE:-vertex-sa.json}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "[1/4] Enabling Vertex AI API on ${PROJECT_ID}…"
gcloud services enable aiplatform.googleapis.com --project="${PROJECT_ID}"

echo "[2/4] Creating service account ${SA_EMAIL}…"
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="AIGW Vertex" --project="${PROJECT_ID}" 2>/dev/null \
  || echo "    (already exists — continuing)"

echo "[3/4] Granting roles/aiplatform.user…"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/aiplatform.user" \
  --condition=None >/dev/null

echo "[4/4] Creating key file ${KEY_FILE}…"
gcloud iam service-accounts keys create "${KEY_FILE}" --iam-account="${SA_EMAIL}"
chmod 600 "${KEY_FILE}"

cat <<EOF

Done.
  Service account : ${SA_EMAIL}
  Role            : roles/aiplatform.user
  Key file        : ${KEY_FILE}   (chmod 600 — keep it secret, never commit)

Next:
  - IAM can take ~60s to propagate; a first call may 403 briefly.
  - For Claude (partner) models, enable each model in Vertex Model Garden.
  - In the AIGW: add a Vertex AI integration, Auth type = Service Account File,
    upload ${KEY_FILE}, set Project ID = ${PROJECT_ID}, Region = global.
EOF
