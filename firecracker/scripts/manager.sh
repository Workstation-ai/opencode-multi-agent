#!/bin/bash
# Manage Firecracker agent microVMs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="/tmp/fc-vms"

show_help() {
  cat << EOF
Firecracker Agent Manager

Usage: $0 <command> [args]

Commands:
  status              Show all running agents
  start <agent>       Start an agent microVM
  stop <agent>        Stop an agent microVM
  stop-all            Stop all agents
  connect <agent>     Connect to an agent (SSH or attach)
  logs <agent>        Show agent logs
  build-all           Build kernel and all rootfs images
  setup-network       Setup networking only

Examples:
  $0 status
  $0 start coder
  $0 connect coder
  $0 stop-all
EOF
}

show_status() {
  echo "Firecracker Agent Status"
  echo "═══════════════════════════════════════════════════════════"
  printf "%-15s %-8s %-15s %-30s\n" "AGENT" "PID" "IP" "STATUS"
  echo "───────────────────────────────────────────────────────────"
  
  for agent_file in "${VM_DIR}"/*.json; do
    [[ -f "${agent_file}" ]] || continue
    name=$(jq -r '.name' "${agent_file}")
    pid=$(jq -r '.pid' "${agent_file}")
    ip=$(jq -r '.ip' "${agent_file}")
    
    if kill -0 "${pid}" 2>/dev/null; then
      status="running"
    else
      status="stopped"
    fi
    
    printf "%-15s %-8s %-15s %-30s\n" "$name" "$pid" "$ip" "$status"
  done
  
  echo ""
  echo "Agents available: $(ls ${AGENTS_DIR:-../../agents}/ 2>/dev/null | tr '\n' ' ')"
}

start_agent() {
  local agent=$1
  if [[ -f "${VM_DIR}/${agent}.json" ]]; then
    pid=$(jq -r '.pid' "${VM_DIR}/${agent}.json")
    if kill -0 "${pid}" 2>/dev/null; then
      echo "Agent ${agent} is already running (PID: ${pid})"
      return 0
    fi
  fi
  
  # Find next available VM ID
  local vm_id=0
  while [[ -f "${VM_DIR}/${agent}.json" ]] || [[ -f "/tmp/fc-${agent}.sock" ]]; do
    vm_id=$((vm_id + 1))
  done
  
  "${SCRIPT_DIR}/launch-agent.sh" "${agent}" "${vm_id}"
}

stop_agent() {
  local agent=$1
  if [[ ! -f "${VM_DIR}/${agent}.json" ]]; then
    echo "Agent ${agent} not found"
    return 1
  fi
  
  pid=$(jq -r '.pid' "${VM_DIR}/${agent}.json")
  if kill -0 "${pid}" 2>/dev/null; then
    echo "Stopping agent ${agent} (PID: ${pid})..."
    kill "${pid}"
    sleep 1
    kill -9 "${pid}" 2>/dev/null || true
  fi
  
  rm -f "${VM_DIR}/${agent}.json" "/tmp/fc-${agent}.sock" "/tmp/fc-${agent}-api.sock"
  echo "Agent ${agent} stopped"
}

stop_all() {
  for agent_file in "${VM_DIR}"/*.json; do
    [[ -f "${agent_file}" ]] || continue
    name=$(jq -r '.name' "${agent_file}")
    stop_agent "${name}"
  done
}

connect_agent() {
  local agent=$1
  if [[ ! -f "${VM_DIR}/${agent}.json" ]]; then
    echo "Agent ${agent} not found. Start it first with: $0 start ${agent}"
    return 1
  fi
  
  ip=$(jq -r '.ip' "${VM_DIR}/${agent}.json")
  echo "Connecting to agent ${agent} at ${ip}..."
  echo "Note: SSH access requires key-based auth setup in the rootfs"
  echo "      For now, use: ssh -o StrictHostKeyChecking=no root@${ip}"
  echo ""
  echo "Or attach via console (if configured):"
  echo "      socat -,rawer,echo=0 UNIX-CONNECT:/tmp/fc-${agent}.sock"
}

show_logs() {
  local agent=$1
  local log_file="/tmp/fc-${agent}.log"
  if [[ -f "${log_file}" ]]; then
    tail -50 "${log_file}"
  else
    echo "No logs found for agent ${agent}"
  fi
}

build_all() {
  echo "Building kernel..."
  "${SCRIPT_DIR}/build-kernel.sh"
  
  echo ""
  echo "Building rootfs images..."
  for agent_dir in "${AGENTS_DIR:-../../agents}"/*/; do
    agent=$(basename "${agent_dir}")
    echo ""
    echo "Building ${agent}..."
    "${SCRIPT_DIR}/build-rootfs.sh" "${agent}"
  done
  
  echo ""
  echo "Build complete!"
}

# Main command dispatch
case "${1:-help}" in
  status)
    show_status
    ;;
  start)
    start_agent "${2:?Agent name required}"
    ;;
  stop)
    stop_agent "${2:?Agent name required}"
    ;;
  stop-all)
    stop_all
    ;;
  connect)
    connect_agent "${2:?Agent name required}"
    ;;
  logs)
    show_logs "${2:?Agent name required}"
    ;;
  build-all)
    build_all
    ;;
  setup-network)
    source "${SCRIPT_DIR}/setup-network.sh"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    show_help
    exit 1
    ;;
esac
