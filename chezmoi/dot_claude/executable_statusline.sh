#!/bin/bash
INPUT=$(cat)

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

DIR=$(basename "$PWD")
BRANCH=$(git branch --show-current 2>/dev/null)

OUT="$MODEL | ctx:$CTX | 5h:$FIVE_H 7d:$SEVEN_D | $COST | $DIR"
[ -n "$BRANCH" ] && OUT="$OUT : $BRANCH"

echo "$OUT"
