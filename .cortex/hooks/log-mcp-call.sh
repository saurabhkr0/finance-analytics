#!/bin/bash
# Log every MCP tool invocation for audit purposes
echo "✅ log-mcp-call hook executed" >&2

INPUT=$(cat)
AUDIT_DIR=".cortex/audit"
mkdir -p "$AUDIT_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('session_id', 'unknown'))
")
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(data.get('tool_name', 'unknown'))
")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys, json; data = json.load(sys.stdin)
print(json.dumps(data.get('tool_input', {})))
")

LOG_ENTRY="{\"timestamp\": \"$TIMESTAMP\", \"session\": \"$SESSION_ID\", \"tool\": \"$TOOL_NAME\", \"input\": $TOOL_INPUT}"

echo "$LOG_ENTRY" >> "$AUDIT_DIR/mcp_audit_$(date -u +%Y%m%d).jsonl"

echo '{"decision": "allow"}'