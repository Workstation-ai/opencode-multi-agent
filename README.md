# OpenCode Multi-Agent System

Multiple specialized agents running as isolated servers. Connect to any agent from a single client.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   CLIENT                        │
│                                                 │
│   ./connect.sh coder    → connects to coder     │
│   ./connect.sh reviewer → connects to reviewer  │
│   ./connect.sh researcher → connects to ...     │
└───────────┬───────────┬───────────┬─────────────┘
            │           │           │
    ┌───────▼──┐  ┌──────▼──┐  ┌────▼────────┐
    │  coder   │  │reviewer │  │ researcher  │
    │ :4001    │  │ :4002   │  │ :4003       │
    │ write    │  │ review  │  │ research    │
    │ code     │  │ code    │  │ topics      │
    └──────────┘  └─────────┘  └─────────────┘
```

## Quick Start

```bash
# Start all agents
docker compose up --build -d

# See what's running
./status.sh

# Connect to an agent
./connect.sh coder
```

## Available Agents

| Agent | Port | Purpose |
|-------|------|---------|
| `coder` | 4001 | Write code, refactor, debug |
| `reviewer` | 4002 | Review code, find issues |
| `researcher` | 4003 | Research, analyze, compare |

## Commands

| Action | Command |
|--------|---------|
| Start all | `docker compose up --build -d` |
| Stop all | `docker compose down` |
| List agents | `./status.sh` |
| Connect | `./connect.sh <agent>` |
| Agent logs | `docker compose logs -f <agent>` |

## Adding a New Agent

1. Create directory: `mkdir agents/myagent`
2. Create `agents/myagent/AGENT.md` with the system prompt
3. Add to `docker-compose.yml`:
   ```yaml
   myagent:
     build:
       context: .
       args:
         AGENT_NAME: myagent
     container_name: agent-myagent
     ports:
       - "4004:4096"
     volumes:
       - workspace:/workspace
     networks:
       - agent-net
     healthcheck:
       test: ["CMD", "curl", "-f", "http://localhost:4096"]
       interval: 10s
       timeout: 5s
       retries: 3
   ```
4. Add to `connect.sh` AGENTS array

## Roadmap

- [ ] Agent discovery API
- [ ] Dynamic agent spawning
- [ ] Agent-to-Agent (A2A) protocol
- [ ] Firecracker isolation for production
