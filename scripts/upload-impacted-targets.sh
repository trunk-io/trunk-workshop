#!/usr/bin/env bash
#
# upload-impacted-targets.sh — tell the Trunk Merge Queue which targets a PR impacts.
#
# Computes the impacted demo targets (frontend / backend) from the PR's changed files
# and POSTs them to Trunk's public API (POST /v1/setImpactedTargets). This runs on
# EVERY PR regardless of the queue's mode — the queue only *uses* impacted targets
# when it's in graph (parallel) mode, so always uploading lets you queue the same PRs
# linearly, then flip graph mode on and re-run to watch them merge as a graph.
#
# Target definition (kept deliberately simple for the demo):
#   - a change under  frontend/  impacts the "frontend" target
#   - a change under  backend/   impacts the "backend" target
#   - anything else impacts "ALL" (forces sequential merging)
#
# Required env:
#   TRUNK_API_TOKEN     Trunk org/repo API token (same secret the analytics upload uses)
#   GITHUB_REPOSITORY   owner/repo (auto-set in GitHub Actions)
#   PR_NUMBER           pull request number
#   PR_SHA              pull request head commit SHA
#   BASE_REF            target branch (e.g. main)
#   GH_TOKEN            token for `gh` to list the PR's changed files
# Optional:
#   TRUNK_API_URL       override the endpoint (default: production)
#
set -euo pipefail

# In State 0 (no Trunk secrets yet) this is expected — log and skip so CI stays green.
if [[ -z "${TRUNK_API_TOKEN:-}" ]]; then
  echo "TRUNK_API_TOKEN is not set — skipping impacted-targets upload. CI stays green; add the secret to enable graph mode."
  exit 0
fi
: "${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY (owner/repo)}"
: "${PR_NUMBER:?set PR_NUMBER}"
: "${PR_SHA:?set PR_SHA}"
: "${BASE_REF:?set BASE_REF}"

API_URL="${TRUNK_API_URL:-https://api.trunk.io/v1/setImpactedTargets}"

# Changed files for this PR (via the GitHub API — no working tree needed).
mapfile -t changed < <(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" \
  --paginate --jq '.[].filename')

declare -A hit=()
for f in "${changed[@]}"; do
  case "${f}" in
    frontend/*) hit[frontend]=1 ;;
    backend/*) hit[backend]=1 ;;
  esac
done

if [[ "${#hit[@]}" -eq 0 ]]; then
  # No known target matched — be safe and mark as impacting everything.
  targets_json='"ALL"'
else
  targets_json="$(printf '%s\n' "${!hit[@]}" | jq -R . | jq -sc .)"
fi

payload="$(jq -nc \
  --arg owner "${GITHUB_REPOSITORY%%/*}" \
  --arg name "${GITHUB_REPOSITORY##*/}" \
  --argjson number "${PR_NUMBER}" \
  --arg sha "${PR_SHA}" \
  --arg base "${BASE_REF}" \
  --argjson targets "${targets_json}" \
  '{repo: {host: "github.com", owner: $owner, name: $name},
    pr: {number: $number, sha: $sha},
    targetBranch: $base,
    impactedTargets: $targets}')"

echo "PR #${PR_NUMBER} (${PR_SHA}) impacted targets: ${targets_json}"
curl -fsS -X POST "${API_URL}" \
  -H "Content-Type: application/json" \
  -H "x-api-token: ${TRUNK_API_TOKEN}" \
  -d "${payload}"
echo
echo "✓ uploaded to ${API_URL}"
