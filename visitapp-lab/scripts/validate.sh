#!/usr/bin/env bash
# scripts/validate.sh - every pre-install check from notes section 3.2.2.4,
# run once per environment. Stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."

for env in dev prod; do
  ns="dso202-$env"
  echo "================ $env ================"

  echo "--> helm lint"
  helm lint ./visitapp -f "environments/$env.yaml"

  echo "--> helm template (renders, checks values.schema.json and required values)"
  helm template "visitapp-$env" ./visitapp -f "environments/$env.yaml" -n "$ns" --skip-tests > "/tmp/visitapp-$env.yaml"
  echo "    $(grep -c '^kind:' "/tmp/visitapp-$env.yaml") objects rendered"

  echo "--> kubectl apply --dry-run=server (the API server checks every field)"
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
  kubectl apply --dry-run=server -n "$ns" -f "/tmp/visitapp-$env.yaml"
done

echo
echo "All checks passed for dev and prod."
