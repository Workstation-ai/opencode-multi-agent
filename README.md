# OpenCode Multi-Agent System (Firecracker)

Multiple specialized agents running as isolated microVMs. Each agent runs in its own Firecracker VM with full kernel isolation.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     HOST MACHINE                        │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Firecracker│  │   Firecracker│  │   Firecracker│    │
│  │   VM: coder  │  │  VM: reviewer│  │ VM: researcher│   │
│  │   172.16.0.11│  │  172.16.0.12 │  │  172.16.0.13 │   │
│  │   :4096      │  │   :4096      │  │   :4096      │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │              │
│         └────────────────┼────────────────┘              │
│                          │                               │
│                    ┌─────▼─────┐                         │
│                    │  fcbr0    │                         │
│                    │ bridge    │                         │
│                    └─────┬─────┘                         │
│                          │                               │
└──────────────────────────┼───────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Client    │
                    │  connects   │
                    │  to any VM  │
                    └─────────────┘
```

## Prerequisites

- Linux host with KVM support
- Firecracker installed (`firecracker --version`)
- Docker (for building rootfs images)

## Quick Start

```bash
# 1. Build everything (kernel + rootfs images)
./firecracker/scripts/manager.sh build-all

# 2. Setup networking
./firecracker/scripts/manager.sh setup-network

# 3. Start agents
./firecracker/scripts/manager.sh start coder
./firecracker/scripts/manager.sh start reviewer
./firecracker/scripts/manager.sh start researcher

# 4. Check status
./firecracker/scripts/manager.sh status

# 5. Connect to an agent
ssh root@172.16.0.11
# Then run: opencode attach http://localhost:4096
```

## Commands

| Command | Description |
|---------|-------------|
| `./firecracker/scripts/manager.sh status` | Show all agents |
| `./firecracker/scripts/manager.sh start <agent>` | Start an agent |
| `./firecracker/scripts/manager.sh stop <agent>` | Stop an agent |
| `./firecracker/scripts/manager.sh stop-all` | Stop all agents |
| `./firecracker/scripts/manager.sh logs <agent>` | Show agent logs |
| `./firecracker/scripts/manager.sh build-all` | Build kernel + rootfs |

## Available Agents

| Agent | IP | Purpose |
|-------|-----|---------|
| `coder` | 172.16.0.11 | Write code, refactor, debug |
| `reviewer` | 172.16.0.12 | Review code, find issues |
| `researcher` | 172.16.0.13 | Research, analyze, compare |

## Adding a New Agent

1. Create directory: `mkdir agents/myagent`
2. Create `agents/myagent/AGENT.md` with the system prompt
3. Build rootfs: `./firecracker/scripts/build-rootfs.sh myagent`
4. Start: `./firecracker/scripts/manager.sh start myagent`

## Why Firecracker?

- **Full isolation**: Each agent runs in its own kernel
- **Security**: VM escape is impossible between agents
- **Resource control**: CPU/memory limits per VM
- **Production ready**: Same tech as AWS Lambda/Fargate

## Comparison with Docker

| Feature | Docker | Firecracker |
|---------|--------|-------------|
| Isolation | Container (shared kernel) | VM (dedicated kernel) |
| Security | Good | Better |
| Boot time | ~100ms | ~125ms |
| Memory overhead | ~10MB | ~50MB |
| Complexity | Simple | More complex |

## Roadmap

- [ ] SSH key-based access to VMs
- [ ] Agent-to-Agent (A2A) communication
- [ ] Dynamic VM scaling
- [ ] Web UI for agent management
- [ ] Prometheus metrics export
