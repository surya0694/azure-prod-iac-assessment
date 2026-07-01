#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <https-url>"
  echo "Example: $0 https://1.2.3.4/healthz"
  exit 1
fi

url="$1"
code=$(curl -k -sS -o /tmp/health-check-body -w "%{http_code}" "$url")
body=$(cat /tmp/health-check-body)

if [[ "$code" == "200" && "$body" == "ok" ]]; then
  echo "Healthy: $url returned HTTP 200 and body 'ok'"
else
  echo "Unhealthy: $url returned HTTP $code and body '$body'" >&2
  exit 2
fi
