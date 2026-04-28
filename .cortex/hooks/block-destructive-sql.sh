#!/bin/bash
echo "✅ block-destructive-sql hook executed" >&2

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_name', ''))
")

if [ "$TOOL_NAME" != "snowflake_sql_execute" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

SQL_UPPER=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
sql = data.get('tool_input', {}).get('sql', '')
print(sql.upper())
")

BLOCKED_PATTERNS=("(^|\s)DROP TABLE" "(^|\s)DROP SCHEMA" "(^|\s)DROP DATABASE" "TRUNCATE" 
                   "DELETE FROM" "ALTER TABLE.*DROP COLUMN")


for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$SQL_UPPER" | grep -qE "$PATTERN"; then
    echo "Blocked: destructive SQL pattern '$PATTERN' detected. Use Snowsight for production DDL changes with proper approval." >&2
    exit 2
  fi
done

echo '{"decision": "allow"}'