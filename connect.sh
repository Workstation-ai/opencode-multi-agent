#!/bin/bash
# Agent connection helper script
# Usage: ./connect.sh [agent-name]

AGENTS=(
  "coder|agent-coder|4096"
  "reviewer|agent-reviewer|4096"
  "researcher|agent-researcher|4096"
)

show_agents() {
  echo "Available agents:"
  echo "─────────────────────────────────────"
  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r name container port <<< "$entry"
    echo "  • $name → $container:$port"
  done
  echo ""
  echo "Usage: ./connect.sh <agent-name>"
}

connect_agent() {
  local name=$1
  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r agent_name container port <<< "$entry"
    if [[ "$agent_name" == "$name" ]]; then
      echo "Connecting to $name..."
      docker exec -it "$container" opencode attach "http://localhost:$port"
      return 0
    fi
  done
  echo "Error: Agent '$name' not found"
  show_agents
  return 1
}

# Main
if [[ $# -eq 0 ]]; then
  show_agents
else
  connect_agent "$1"
fi
