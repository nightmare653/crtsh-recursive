#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

INPUT_FILE=${1:-domains.txt}
RATE_LIMIT_SECONDS=${RATE_LIMIT_SECONDS:-1}   # throttle between crt.sh requests
MAX_RETRIES=${MAX_RETRIES:-3}                 # retries for curl failures
SKIP_DONE=${SKIP_DONE:-1}                     # skip domains that are already processed

# Ensure dependencies exist
for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  }
done

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: input file '$INPUT_FILE' not found." >&2
  exit 1
fi

# Function to query crt.sh and extract subs + wildcard roots
fetch_crt_for_domain() {
  local current="$1"
  local subs_file="$2"
  local wildcards_file="$3"
  shift 3

  # nameref to the associative array and queue array
  declare -n _seen="$1"
  declare -n _queue="$2"

  echo "    [*] Querying crt.sh for *.$current"

  local tmpfile
  tmpfile=$(mktemp)
  local attempt=1
  local http_code="000"

  # Timeout & retry logic
  while (( attempt <= MAX_RETRIES )); do
    http_code=$(curl -m 20 --connect-timeout 10 -sS -w "%{http_code}" \
        "https://crt.sh/?q=%25.${current}&output=json" \
        -o "$tmpfile" || echo "000")

    if [[ "$http_code" == "200" ]]; then
        break
    fi

    echo "    [!] HTTP $http_code for $current (attempt $attempt/$MAX_RETRIES)"
    ((attempt++))
    sleep "$RATE_LIMIT_SECONDS"
  done

  if [[ "$http_code" != "200" ]]; then
    echo "    [!] Giving up on $current"
    rm -f "$tmpfile"
    return
  fi

  local response
  response=$(<"$tmpfile")
  rm -f "$tmpfile"

  if ! echo "$response" | jq empty >/dev/null 2>&1; then
    echo "    [!] Invalid JSON from crt.sh for $current (skipping)"
    return
  fi

  if [[ "$(echo "$response" | jq 'length')" -eq 0 ]]; then
    echo "    [*] No results for $current"
    return
  fi

  # Extract all name_value lines, split, dedupe
  local names
  names=$(
    echo "$response" \
      | jq -r '.[].name_value' \
      | tr '\r' '\n' \
      | sed '/^$/d' \
      | sort -u
  )

  while IFS= read -r name; do
    # Strip leading/trailing whitespace
    name=${name##+([[:space:]])}
    name=${name%%+([[:space:]])}
    [[ -z "$name" ]] && continue

    # ----- FIXED WILDCARD DETECTION -----
    # If it starts with "*.", treat as wildcard
    if [[ "${name:0:2}" == "*." ]]; then
      # Clean: "*.ae.aliexpress.com" -> "ae.aliexpress.com"
      local clean=${name#*.}
      echo "$clean" >> "$wildcards_file"

      # enqueue cleaned wildcard domain for further crt.sh queries
      if [[ -z "${_seen[$clean]:-}" ]]; then
        _queue+=("$clean")
      fi
    else
      # Non-wildcard → subdomain
      echo "$name" >> "$subs_file"
    fi
    # ------------------------------------
  done <<< "$names"

  sleep "$RATE_LIMIT_SECONDS"
}

while IFS= read -r domain || [[ -n "$domain" ]]; do
  [[ -z "$domain" ]] && continue
  [[ "$domain" =~ ^[[:space:]]*# ]] && continue

  domain=${domain##+([[:space:]])}
  domain=${domain%%+([[:space:]])}
  [[ -z "$domain" ]] && continue

  echo "[+] Processing $domain"

  mkdir -p "$domain"
  subs_file="$domain/subs.txt"
  wildcards_file="$domain/wildcards_clean.txt"

  # Skip domains already processed
  if (( SKIP_DONE )) && [[ -s "$subs_file" ]]; then
    echo "[*] Skipping $domain (subs.txt already exists)"
    echo
    continue
  fi

  : > "$subs_file"
  : > "$wildcards_file"

  declare -A seen=()
  queue=("$domain")

  while ((${#queue[@]})); do
    current="${queue[0]}"
    queue=("${queue[@]:1}")

    if [[ -n "${seen[$current]:-}" ]]; then
      continue
    fi
    seen["$current"]=1

    fetch_crt_for_domain "$current" "$subs_file" "$wildcards_file" seen queue
  done

  sort -u -o "$subs_file" "$subs_file"
  sort -u -o "$wildcards_file" "$wildcards_file"

  echo "[+] Done → $domain/"
  echo

done < "$INPUT_FILE"