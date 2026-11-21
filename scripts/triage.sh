#!/usr/bin/env bash
# scripts/triage.sh - Log triage script for Craon DevOps Assignment
# Usage: ./scripts/triage.sh [path/to/access.log]
# Analyzes:
# 1. Top five endpoints by request volume
# 2. Count of 5xx responses per minute
# 3. Slowest ten requests by response time

set -euo pipefail

LOG_FILE="${1:-sample/access.log}"

if [ ! -f "$LOG_FILE" ]; then
  echo "Error: Log file not found at '$LOG_FILE'" >&2
  echo "Usage: $0 [path/to/access.log]" >&2
  exit 1
fi

echo "=========================================================="
echo "          LOG TRIAGE REPORT: $LOG_FILE"
echo "=========================================================="
echo ""

# 1. Top five endpoints
echo "--- 1. TOP 5 ENDPOINTS ---"
# Extracts request uri ($7 in standard extended log format: "$1 $2 $3 [$4 $5] \"$6 $7 $8\" $9 $10 $11")
awk '{print $7}' "$LOG_FILE" \
  | cut -d'?' -f1 \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -n 5 \
  | awk '{printf "%-7d %s\n", $1, $2}'

echo ""
echo "--- 2. 5xx RESPONSES PER MINUTE ---"
# Grep for status codes in 500-599 ($9), extract minute timestamp ($4 without seconds), count per minute
awk '$9 ~ /^5[0-9]{2}$/ {print $4}' "$LOG_FILE" \
  | tr -d '[' \
  | cut -d':' -f1-3 \
  | sort \
  | uniq -c \
  | awk '{printf "%-7d %s\n", $1, $2}'

echo ""
echo "--- 3. SLOWEST 10 REQUESTS ---"
# Sort by response time ($11 numeric descending), display time, status, method, URL, and client IP
awk '{print $11, "sec | status:", $9, "|", $6, $7, "| client:", $1}' "$LOG_FILE" \
  | sort -rn \
  | head -n 10

echo ""
echo "=========================================================="
echo "                  TRIAGE COMPLETED"
echo "=========================================================="
