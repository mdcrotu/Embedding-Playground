#!/usr/bin/env bash
# tools/hooks/ai_commit_msg.sh
# Auto-generate a Conventional Commit message using an LLM.
# Backend selected by AI_BACKEND: ollama | openai | anthropic  (default: ollama)
# - Safely builds JSON (jq --rawfile or python3) so diffs aren't interpolated.
# - Captures HTTP code separately; accepts body-first on success.
# - Sanitizes/normalizes to Conventional Commits.
# - Light heuristics to remap type (build/ci/docs/test/style/perf) and infer scope.

set -euo pipefail

# ---- Inputs from pre-commit ----
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

# ---- Paths for temp artifacts ----
HOOKS_DIR=".git/hooks"
LOG="$HOOKS_DIR/_ai_commit.log"
BODY_JSON="$HOOKS_DIR/_ai_commit_body.json"
PAYLOAD_JSON="$HOOKS_DIR/_ai_payload.json"
HTTP_CODE_FILE="$HOOKS_DIR/_ai_httpcode.txt"
DIFF_FILE="$HOOKS_DIR/_ai_diff.txt"

mkdir -p "$HOOKS_DIR"

# If the buffer already has non-comment, non-whitespace text, don't override
if awk 'BEGIN{nonempty=0} /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next} {nonempty=1} END{exit !nonempty}' \
     "$COMMIT_MSG_FILE"; then
  exit 0
fi

# Load repo-local overrides if present (optional)
if [ -f .env.ai ]; then
  # shellcheck disable=SC1091
  . ./.env.ai
fi

# ---- Backend config (env overrides allowed) ----
: "${AI_BACKEND:=ollama}"                  # ollama | openai | anthropic

# Ollama (local)
: "${OLLAMA_URL:=http://localhost:11434/api/chat}"
: "${OLLAMA_MODEL:=llama3:8b}"
: "${CTX_TOKENS:=4096}"
: "${TEMP:=0.3}"

# OpenAI (Responses API)
: "${OPENAI_URL:=https://api.openai.com/v1/responses}"
: "${OPENAI_MODEL:=gpt-4o-mini}"

# Anthropic (Messages API)
: "${ANTHROPIC_URL:=https://api.anthropic.com/v1/messages}"
: "${ANTHROPIC_MODEL:=claude-sonnet-4-20250514}"
: "${MAX_MODEL_TOKENS:=512}"

# Shared
: "${MAX_DIFF_LINES:=600}"
: "${CURL_TIMEOUT:=60}"

# ---- Collect staged diff to file (no color, minimal context) ----
git diff --cached --unified=0 --no-color | head -n "$MAX_DIFF_LINES" > "$DIFF_FILE" || true
if [ ! -s "$DIFF_FILE" ]; then
  exit 0
fi

# ---- Tool availability ----
have_jq=0; have_py=0
command -v jq >/dev/null 2>&1 && have_jq=1
command -v python3 >/dev/null 2>&1 && have_py=1
if (( ! have_jq && ! have_py )); then
  echo "chore: commit (AI message generation failed; install jq or python3)" > "$COMMIT_MSG_FILE"
  exit 0
fi

# ---------------- Prompts ----------------
read -r SYS_PROMPT <<'SYS'
You write Conventional Commit messages from staged diffs.

STRICT RULES — DO NOT VIOLATE:
- Output ONLY the final commit message. No preface, no explanation, no quotes, no code fences.
- First line: type(scope?): summary
  where type ∈ {feat, fix, refactor, docs, test, chore, perf, build, ci, style}
- Summary ≤ 72 chars, imperative mood (e.g., "add", "fix", "remove").
- If there is more than one file or multiple hunks, include up to 3 bullet points after a blank line.
  Bullets must be short (“- …”), each focused on one key change or rationale.
- Prefer accurate type/scope: e.g., Makefile/build tooling → build; GitHub Actions → ci; docs only → docs; tests only → test; performance tweaks → perf.
- NO other text besides the commit message.
SYS

read -r USER_LEADIN <<'TXT'
Create a Conventional Commit message for the following staged diff.

<DIFF>
TXT
USER_TRAILIN="</DIFF>"

# ---------- Payload builders (backend-specific) ----------
build_payload_ollama() {
  if (( have_jq )); then
    jq -n \
      --arg model   "$OLLAMA_MODEL" \
      --arg system  "$SYS_PROMPT" \
      --arg leadin  "$USER_LEADIN" \
      --rawfile diff "$DIFF_FILE" \
      --arg trailin "$USER_TRAILIN" \
      --argjson num_ctx "$CTX_TOKENS" \
      --argjson temp    "$TEMP" \
      '{
         model: $model,
         messages: [
           {role:"system", content:$system},
           {role:"user",   content: ($leadin + "\n" + $diff + "\n" + $trailin)}
         ],
         options: {num_ctx:$num_ctx, temperature:$temp},
         stream: false
       }'
  else
    python3 - "$OLLAMA_MODEL" "$SYS_PROMPT" "$USER_LEADIN" "$USER_TRAILIN" "$DIFF_FILE" "$CTX_TOKENS" "$TEMP" <<'PY'
import sys, json, io
model, system, leadin, trailin, diff_file, num_ctx, temp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6]), float(sys.argv[7])
with io.open(diff_file, 'r', encoding='utf-8', errors='replace') as f:
    diff = f.read()
prompt = f"{leadin}\n{diff}\n{trailin}"
print(json.dumps({
    "model": model,
    "messages": [
        {"role": "system", "content": system},
        {"role": "user",   "content": prompt}
    ],
    "options": {"num_ctx": num_ctx, "temperature": temp},
    "stream": False
}))
PY
  fi
}

build_payload_openai() {
  # OpenAI Responses API
  if (( have_jq )); then
    jq -n \
      --arg model   "$OPENAI_MODEL" \
      --arg system  "$SYS_PROMPT" \
      --arg leadin  "$USER_LEADIN" \
      --rawfile diff "$DIFF_FILE" \
      --arg trailin "$USER_TRAILIN" \
      '{
        model: $model,
        input: [
          {"role":"system","content": $system},
          {"role":"user",  "content": ($leadin + "\n" + $diff + "\n" + $trailin)}
        ]
      }'
  else
    python3 - "$OPENAI_MODEL" "$SYS_PROMPT" "$USER_LEADIN" "$USER_TRAILIN" "$DIFF_FILE" <<'PY'
import sys, json, io
model, system, leadin, trailin, diff_file = sys.argv[1:]
with io.open(diff_file, 'r', encoding='utf-8', errors='replace') as f:
    diff = f.read()
payload = {
  "model": model,
  "input": [
    {"role":"system","content": system},
    {"role":"user",  "content": f"{leadin}\n{diff}\n{trailin}"}
  ]
}
print(json.dumps(payload))
PY
  fi
}

build_payload_anthropic() {
  # Anthropic Messages API
  if (( have_jq )); then
    jq -n \
      --arg model   "$ANTHROPIC_MODEL" \
      --arg system  "$SYS_PROMPT" \
      --arg leadin  "$USER_LEADIN" \
      --rawfile diff "$DIFF_FILE" \
      --arg trailin "$USER_TRAILIN" \
      --argjson max_tokens "$MAX_MODEL_TOKENS" \
      '{
        model: $model,
        max_tokens: $max_tokens,
        system: $system,
        messages: [
          {"role":"user","content": ($leadin + "\n" + $diff + "\n" + $trailin)}
        ]
      }'
  else
    python3 - "$ANTHROPIC_MODEL" "$SYS_PROMPT" "$USER_LEADIN" "$USER_TRAILIN" "$DIFF_FILE" "$MAX_MODEL_TOKENS" <<'PY'
import sys, json, io
model, system, leadin, trailin, diff_file, max_tokens = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
with io.open(diff_file, 'r', encoding='utf-8', errors='replace') as f:
    diff = f.read()
payload = {
  "model": model,
  "max_tokens": max_tokens,
  "system": system,
  "messages": [
    {"role":"user","content": f"{leadin}\n{diff}\n{trailin}"}
  ]
}
print(json.dumps(payload))
PY
  fi
}

# ---------- Build payload + choose URL/headers ----------
case "$AI_BACKEND" in
  openai)
    build_payload_openai > "$PAYLOAD_JSON"
    CURL_URL="$OPENAI_URL"
    : "${OPENAI_API_KEY:?OPENAI_API_KEY not set}"
    CURL_ARGS=(-H "Content-Type: application/json" -H "Authorization: Bearer ${OPENAI_API_KEY}")
    ;;
  anthropic)
    build_payload_anthropic > "$PAYLOAD_JSON"
    CURL_URL="$ANTHROPIC_URL"
    : "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"
    CURL_ARGS=(
      -H "Content-Type: application/json"
      -H "x-api-key: ${ANTHROPIC_API_KEY}"
      -H "anthropic-version: 2023-06-01"
    )
    ;;
  *) # ollama
    build_payload_ollama > "$PAYLOAD_JSON"
    CURL_URL="$OLLAMA_URL"
    CURL_ARGS=(-H "Content-Type: application/json")
    ;;
esac

# ---------------- Call backend ----------------
: > "$HTTP_CODE_FILE"
curl -sS -m "$CURL_TIMEOUT" \
  "${CURL_ARGS[@]}" \
  --data-binary @"$PAYLOAD_JSON" \
  -o "$BODY_JSON" \
  -w "%{http_code}" \
  "$CURL_URL" > "$HTTP_CODE_FILE" || true

HTTP_CODE="$(tr -d '\r\n' < "$HTTP_CODE_FILE" || echo 000)"
BODY="$(cat "$BODY_JSON" 2>/dev/null || true)"

# ------------- Extract response text -------------
extract_msg_openai() {
  if (( have_jq )); then
    # Prefer .output_text if present (Responses API)
    jq -r '(.output_text // empty)' 2>/dev/null
  else
    python3 - <<'PY'
import sys, json
try:
  data = json.load(sys.stdin)
  print((data.get("output_text") or "").strip())
except Exception:
  pass
PY
  fi
}

extract_msg_anthropic() {
  if (( have_jq )); then
    jq -r '.content[0].text // empty' 2>/dev/null
  else
    python3 - <<'PY'
import sys, json
try:
  data = json.load(sys.stdin)
  blocks = data.get("content") or []
  txt = ""
  if blocks and isinstance(blocks[0], dict):
    txt = blocks[0].get("text","")
  print((txt or "").strip())
except Exception:
  pass
PY
  fi
}

case "$AI_BACKEND" in
  openai)    MSG="$(printf "%s" "$BODY" | extract_msg_openai    || true)";;
  anthropic) MSG="$(printf "%s" "$BODY" | extract_msg_anthropic || true)";;
  *)         # ollama
             if (( have_jq )); then
               MSG="$(printf "%s" "$BODY" | jq -r '.message.content // .response // empty' 2>/dev/null || true)"
             else
               MSG=""
             fi
             ;;
esac

# ------------- Sanitizer: enforce Conventional Commits -------------
sanitize_commit() {
  awk '
    BEGIN { got=0; printed_blank=0 }
    {
      g=$0
      sub(/\r$/, "", g)
      # skip boilerplate-like lines
      if (!got) {
        if (g ~ /^[[:space:]]*(Here is|This message|Note:)/) next
        if (g ~ /^[[:space:]]*$/) next
        # strip surrounding quotes
        sub(/^"[[:space:]]*/, "", g); sub(/[[:space:]]*"$/, "", g)
        # if looks like conventional summary, keep it
        if (g ~ /^(feat|fix|refactor|docs|test|chore|perf|build|ci|style)(\([^)]+\))?:[[:space:]].+/) {
          print g; got=1; next
        }
        # otherwise coerce into chore summary
        print "chore: " g; got=1; next
      } else {
        # keep only bullet lines; allow a single blank line separating summary and bullets
        if (g ~ /^[[:space:]]*$/) { if (!printed_blank) { print ""; printed_blank=1 } ; next }
        if (g ~ /^[[:space:]]*[-*][[:space:]]+/) print g
      }
    }
  '
}

MSG_STRICT="$(printf "%s\n" "$MSG" | sanitize_commit)"
if [ -z "$(printf "%s" "$MSG_STRICT" | tr -d '[:space:]')" ]; then
  MSG_STRICT="chore: commit"
fi

# ------------- Type remap + scope inference (enhanced) -------------
CHANGED_FILES=$(git diff --cached --name-only | tr -d '\r' || true)

# Quick counts / flags
TOP_DIR=$(printf "%s\n" "$CHANGED_FILES" | awk -F/ 'NF>1{print $1} NF==1{print "."}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
[ -z "$TOP_DIR" ] && TOP_DIR="."

only_md=$(printf "%s\n" "$CHANGED_FILES" | awk '{if($0 ~ /\.md$/) c++} END{print (NR>0 && c==NR) ? 1 : 0}')
only_tests=$(printf "%s\n" "$CHANGED_FILES" | awk '{if($0 ~ /(^|\/)(tests?|__tests__)(\/|$)|_test\.py$|\.spec\./) c++} END{print (NR>0 && c==NR) ? 1 : 0}')
has_ci=$(printf "%s\n" "$CHANGED_FILES" | grep -Eq '^\.github/workflows/|^\.gitlab-ci\.y(a)?ml$' && echo 1 || echo 0)
has_make=$(printf "%s\n" "$CHANGED_FILES" | grep -q '^Makefile$' && echo 1 || echo 0)
has_docker=$(printf "%s\n" "$CHANGED_FILES" | grep -Eq '(^|/)(Dockerfile|docker-compose(\.ya?ml)?)$' && echo 1 || echo 0)
has_terraform=$(printf "%s\n" "$CHANGED_FILES" | grep -Eq '\.tf$' && echo 1 || echo 0)
has_buildfiles=$(printf "%s\n" "$CHANGED_FILES" | grep -E -q '(^|/)(Makefile|pyproject\.toml|requirements\.(txt|in)|package(-lock)?\.json|uv\.lock)$' && echo 1 || echo 0)
has_ruff_black_cfg=$(printf "%s\n" "$CHANGED_FILES" | grep -E -q '(^|/)(\.ruff\.toml|ruff\.toml|pyproject\.toml|\.pre-commit-config\.ya?ml)$' && echo 1 || echo 0)
has_benchmarks=$(printf "%s\n" "$CHANGED_FILES" | grep -Eq '(^|/)(benchmarks?|perf)/' && echo 1 || echo 0)

# Split sanitized message
summary=$(printf "%s\n" "$MSG_STRICT" | sed -n '1p')
rest=$(printf "%s\n" "$MSG_STRICT" | sed '1d')

# Ensure a type prefix exists
if ! printf "%s" "$summary" | grep -Eq '^(feat|fix|refactor|docs|test|chore|perf|build|ci|style)(\([^)]+\))?: '; then
  summary="chore: $summary"
fi

# Heuristic remap priority (topmost wins)
if [ "$only_md" = 1 ]; then
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/docs\1/')
elif [ "$only_tests" = 1 ]; then
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/test\1/')
elif [ "$has_ci" = 1 ]; then
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/ci\1/')
elif [ "$has_docker" = 1 ] || [ "$has_make" = 1 ] || [ "$has_buildfiles" = 1 ] || [ "$has_terraform" = 1 ]; then
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/build\1/')
elif [ "$has_ruff_black_cfg" = 1 ]; then
  # treat formatter/linter config tweaks as style (or swap to chore if you prefer)
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/style\1/')
elif [ "$has_benchmarks" = 1 ]; then
  summary=$(printf "%s" "$summary" | sed -E 's/^[a-z]+(\(|:)/perf\1/')
fi

# Add a scope if missing and a meaningful top dir exists
if ! printf "%s" "$summary" | grep -Eq '^[a-z]+\([^)]+\): '; then
  scope="$TOP_DIR"
  # avoid silly scope for single-file root edits
  if [ "$scope" != "." ]; then
    summary=$(printf "%s" "$summary" | sed -E "s/^([a-z]+): /\1(${scope}): /")
  fi
fi

# Reassemble with bullets (if any survived sanitization)
if [ -n "$(printf "%s" "$rest" | tr -d '[:space:]')" ]; then
  MSG_FINAL=$(printf "%s\n\n%s\n" "$summary" "$rest")
else
  MSG_FINAL=$(printf "%s\n" "$summary")
fi

# Add a trailer so we can see which backend/model produced this message
: "${AI_TRAILER:=1}"  # set AI_TRAILER=0 to disable
if [ "$AI_TRAILER" = "1" ]; then
  case "$AI_BACKEND" in
    openai)    MODEL_USED="${OPENAI_MODEL}";;
    anthropic) MODEL_USED="${ANTHROPIC_MODEL}";;
    *)         MODEL_USED="${OLLAMA_MODEL}";;
  esac
  # print backend/model to terminal before writing commit message
  echo "[ai-commit] Using backend=$AI_BACKEND model=$MODEL_USED"
  MSG_FINAL="$(printf "%s\n\nAI-Commit: %s %s\n" "$MSG_FINAL" "$AI_BACKEND" "$MODEL_USED")"
fi

# ---- Accept on message (body-first); log on failure ----
if [ -n "$(printf "%s" "$MSG_FINAL" | tr -d '[:space:]')" ]; then
  printf "%s" "$MSG_FINAL" > "$COMMIT_MSG_FILE"
  # Optional breadcrumb:
  echo "[ai-commit] backend=$AI_BACKEND model=$MODEL_USED http=$HTTP_CODE" >> "$LOG"
  exit 0
fi

# Failure path: log details and write a placeholder
{
  echo "---- $(date) ----"
  echo "HTTP: $HTTP_CODE"
  echo "Backend: $AI_BACKEND"
  echo "URL:  ${CURL_URL:-?}"
  echo "Model: ${OLLAMA_MODEL:-}${OPENAI_MODEL:-}${ANTHROPIC_MODEL:-}"
  echo "Timeout: $CURL_TIMEOUT"
  echo "CTX_TOKENS: $CTX_TOKENS"
  echo "TEMP: $TEMP"
  echo "Diff lines used: $(wc -l < "$DIFF_FILE" | tr -d ' ')"
  echo "Payload (first 400 chars):"
  head -c 400 "$PAYLOAD_JSON" 2>/dev/null || true
  echo
  echo "Body (first 800 chars):"
  printf "%s" "$BODY" | head -c 800; echo
} >> "$LOG" 2>&1

echo "chore: commit (AI commit message generation failed; see $LOG)" > "$COMMIT_MSG_FILE"
