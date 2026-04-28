#!/bin/bash
echo "✅ cost-guard hook executed" >&2

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_name', ''))
")

if [ "$TOOL_NAME" != "snowflake_sql_execute" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

QUERY=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('sql', ''))
")

SQL_UPPER=$(echo "$QUERY" | tr '[:lower:]' '[:upper:]')

LARGE_TABLES=("TRANSACTIONS" "COMPLIANCE_ALERTS" "PARSED_DOCS" "DOC_CHUNKS")

for TABLE in "${LARGE_TABLES[@]}"; do
  if echo "$SQL_UPPER" | grep -q "$TABLE"; then
    if ! echo "$SQL_UPPER" | grep -qE "(WHERE|LIMIT|SAMPLE|TOP)"; then
      echo "Blocked: Cost guard: query references large table $TABLE without a WHERE, LIMIT, or SAMPLE clause. Add a filter to avoid a full table scan." >&2
      exit 2
    fi
  fi
done

echo '{"decision": "allow"}'