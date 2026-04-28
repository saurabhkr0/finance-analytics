#!/bin/bash
echo "✅ pii-scanner hook executed" >&2

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_name', ''))
")

if [ "$TOOL_NAME" != "Write" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('file_path', ''))
")

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('content', ''))
")

PII_FOUND=""

if echo "$CONTENT" | grep -qiE '[0-9]{3}-[0-9]{2}-[0-9]{4}'; then
  PII_FOUND="$PII_FOUND SSN pattern detected."
fi

if echo "$CONTENT" | grep -qiE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}'; then
  PII_FOUND="$PII_FOUND Email address detected."
fi

if echo "$CONTENT" | grep -qiE '[0-9]{10,16}'; then
  PII_FOUND="$PII_FOUND Possible account/card number detected."
fi

if [ -n "$PII_FOUND" ]; then
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"WARNING: Potential PII found in $FILE_PATH:$PII_FOUND Review before committing to Git.\"}}"
else
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"\"}}"the
fi