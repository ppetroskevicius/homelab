#!/bin/bash
INPUT=$(cat)

# Which subscription funds this session? transcript_path lives under the active Claude
# config dir (CLAUDE_CONFIG_DIR, or ~/.claude by default).
CFG_DIR=$(echo "$INPUT" | jq -r '.transcript_path // ""')
case "$CFG_DIR" in
  */projects/*) CFG_DIR="${CFG_DIR%/projects/*}" ;;
  *)            CFG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
esac
CFG_DIR="${CFG_DIR%/}"

# The default config dir keeps .claude.json at $HOME, not inside ~/.claude.
case "$CFG_DIR" in
  "$HOME/.claude") CFG_JSON="$HOME/.claude.json" ;;
  *)               CFG_JSON="$CFG_DIR/.claude.json" ;;
esac

SUB=$(jq -r '(.oauthAccount.organizationType // "") |
  if   . == "claude_enterprise" then "E"
  elif . == "claude_max"        then "M"
  elif . == "claude_pro"        then "P"
  elif . == "claude_team"       then "T"
  else "?" end' "$CFG_JSON" 2>/dev/null)
[ -n "$SUB" ] || SUB="?"

MODEL=$(echo "$INPUT" | jq -r '(.model.display_name // "") | ascii_downcase |
  if test("mythos") then "M"
  elif test("fable") then "F"
  elif test("opus") then "O"
  elif test("sonnet") then "S"
  elif test("haiku") then "H"
  else "?" end')

CTX=$(echo    "$INPUT" | jq -r '(.context_window.used_percentage // 0 | round | tostring) + "%"')
FIVE_H=$(echo "$INPUT" | jq -r '(.rate_limits.five_hour.used_percentage // 0 | round | tostring) + "%"')
SEVEN_D=$(echo "$INPUT" | jq -r '(.rate_limits.seven_day.used_percentage // 0 | round | tostring) + "%"')
COST=$(echo   "$INPUT" | jq -r '"$" + (.cost.total_cost_usd // 0 | . * 100 | round / 100 | tostring)')
# Lines added/removed by Claude's edits this session (built-in counters, no git call).
LINES=$(echo  "$INPUT" | jq -r '"+\(.cost.total_lines_added // 0)/-\(.cost.total_lines_removed // 0)"')

# Prompt cache (main conversation): "<session hit ratio>/<ttl>", "/COLD" once the TTL lapsed, "!N" =
# unexplained prefix rebuilds (run /usage for the cause). "-" until the first API response, "off" if
# the provider reports no caching (warm is false there too, so it must not read as COLD).
CACHE=$(echo "$INPUT" | jq -r '
  if .prompt_cache == null then "-"
  elif .prompt_cache.caching_observed != true then "off"
  else .prompt_cache
       | (if .hit_ratio == null then "?" else "\(.hit_ratio * 100 | round)%" end)
         + "/" + (if .warm then .ttl else "COLD" end)
         + (if .misses > 0 then "!\(.misses)" else "" end)
  end' 2>/dev/null)
[ -n "$CACHE" ] || CACHE="-"

DIR=$(basename "$PWD")

OUT="$SUB | $MODEL | ctx:$CTX | 5h:$FIVE_H 7d:$SEVEN_D | cache:$CACHE | $COST $LINES | $DIR"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  # Detached HEAD (e.g. Claude Code worktrees) has no branch: show short SHA.
  [ -z "$BRANCH" ] && BRANCH=$(git rev-parse --short HEAD 2>/dev/null)
  [ -n "$BRANCH" ] && OUT="$OUT : $BRANCH"

  # Linked worktrees have a git-dir under .../.git/worktrees/<name>.
  GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null)
  case "$GIT_DIR" in
    */worktrees/*) OUT="$OUT wt:$(basename "$GIT_DIR")" ;;
  esac
fi

echo "$OUT"
