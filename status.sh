#!/bin/bash
# List all agents and their status

echo "Agent Status"
echo "═══════════════════════════════════════════════════════════"
printf "%-15s %-20s %-10s %s\n" "AGENT" "CONTAINER" "STATUS" "PORT"
echo "───────────────────────────────────────────────────────────"

docker ps --format "{{.Names}}\t{{.Status}}" | while read line; do
  name=$(echo "$line" | cut -f1)
  status=$(echo "$line" | cut -f2)
  
  if [[ "$name" == agent-* ]]; then
    agent_name=${name#agent-}
    port=$(docker port "$name" 4096 2>/dev/null | head -1 | cut -d: -f2)
    printf "%-15s %-20s %-10s %s\n" "$agent_name" "$name" "$status" "${port:-?}"
  fi
done

echo ""
echo "Connect: ./connect.sh <agent-name>"
