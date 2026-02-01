# 🏗️ Architecture

## System Overview

OpenClaw/Clawbot is an AI agent gateway that orchestrates LLM-powered agents with secure skill execution.

## Components

### 1. Gateway (Core)

The gateway is the central hub that:
- Manages WebSocket connections from clients
- Routes requests to appropriate agents
- Handles authentication and authorization
- Coordinates skill execution
- Manages session state

```
┌─────────────────────────────────────────────────────────────┐
│                     Gateway Process                          │
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐ │
│  │ HTTP/WS Server │  │ Agent Manager  │  │ Skill Router  │ │
│  │   (Port 18789) │  │                │  │               │ │
│  └────────────────┘  └────────────────┘  └───────────────┘ │
│           │                  │                   │          │
│           ▼                  ▼                   ▼          │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐ │
│  │ Session Store  │  │ Model Adapter  │  │ Sandbox Pool  │ │
│  │ (~/.openclaw/) │  │ (Multi-Model)  │  │   (Docker)    │ │
│  └────────────────┘  └────────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 2. Agents

Agents are LLM-powered workers that:
- Receive tasks from the gateway
- Plan and execute multi-step operations
- Use skills/tools to interact with the world
- Maintain conversation context

**Agent Types:**
- **Default**: General-purpose assistant
- **Coder**: Specialized for code generation and editing
- **Researcher**: Optimized for information gathering

### 3. Sandbox Layer

Security-critical component that:
- Isolates skill execution from the host
- Enforces resource limits (CPU, memory, network)
- Provides clean, reproducible environments
- Prevents privilege escalation

```
┌─────────────────────────────────────────────────────────────┐
│                    Sandbox Container                         │
│                                                              │
│  ┌─────────────┐  Capabilities:                             │
│  │   Skill     │  - CAP_DROP: ALL                           │
│  │  Execution  │  - Read-only root filesystem               │
│  │             │  - No network (default)                    │
│  └─────────────┘  - PID/memory limits                       │
│                   - Seccomp/AppArmor profiles               │
│                                                              │
│  Mounts:                                                     │
│  - /workspace (optional, scoped)                            │
│  - /tmp (tmpfs)                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4. Skills

Skills are capabilities that agents can use:

| Category | Skills | Description |
|----------|--------|-------------|
| **Core** | clawhub, mcporter | Package management, MCP adapter |
| **AI** | gemini, openai-whisper | Model providers, STT |
| **Secrets** | 1password | Secure credential access |
| **Productivity** | obsidian, himalaya | Knowledge base, email |
| **CLI** | various | System tools and utilities |

## Data Flow

```
User Request
     │
     ▼
┌─────────────┐
│  Control UI │ ◄─── Browser (http://127.0.0.1:18789)
└─────────────┘
     │ WebSocket
     ▼
┌─────────────┐
│   Gateway   │ ◄─── Token Authentication
└─────────────┘
     │
     ├──────────────────────────────┐
     │                              │
     ▼                              ▼
┌─────────────┐              ┌─────────────┐
│   Agent     │              │    Model    │
│  (Planner)  │ ◄──────────► │  Provider   │
└─────────────┘              │ (API Call)  │
     │                       └─────────────┘
     │ Skill Call
     ▼
┌─────────────┐
│   Sandbox   │ ◄─── Docker Container
└─────────────┘
     │
     ▼
┌─────────────┐
│   Result    │
└─────────────┘
```

## Persistence

All persistent data lives on the host:

```
~/.openclaw/
├── openclaw.json          # Gateway configuration
├── agents/
│   └── <agent-id>/
│       └── sessions/      # Conversation history
├── workspace/             # Agent working directory
├── sandboxes/             # Sandbox metadata
└── logs/                  # Gateway logs
```

## Network Architecture

```
                    External Network
                          │
                          │ (Firewall)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Docker Host                              │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              openclaw-network (bridge)               │    │
│  │                                                      │    │
│  │  ┌──────────────┐                                   │    │
│  │  │   Gateway    │◄── 127.0.0.1:18789 (host)        │    │
│  │  │  Container   │                                   │    │
│  │  └──────────────┘                                   │    │
│  │         │                                           │    │
│  │         │ Docker Socket                             │    │
│  │         ▼                                           │    │
│  │  ┌──────────────┐                                   │    │
│  │  │   Sandbox    │◄── network: none (isolated)      │    │
│  │  │  Container   │                                   │    │
│  │  └──────────────┘                                   │    │
│  │                                                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  Volumes:                                                    │
│  - ~/.openclaw → /home/node/.openclaw                       │
│  - /var/run/docker.sock → /var/run/docker.sock              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Multi-Model Routing

The gateway supports intelligent model routing:

```javascript
{
  "models": {
    "routing": {
      "planner": "claude-sonnet-4-20250514",  // Complex reasoning
      "coder": "claude-sonnet-4-20250514",      // Code generation
      "fast": "gpt-4o-mini",             // Quick responses
      "vision": "gpt-4o"                 // Image analysis
    }
  }
}
```

## Scaling Considerations

### Single Host (Current)
- One gateway process
- Multiple concurrent agents
- Shared sandbox pool

### Future: Multi-Host
```
                    Load Balancer
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │Gateway 1│   │Gateway 2│   │Gateway 3│
      └─────────┘   └─────────┘   └─────────┘
           │             │             │
           └─────────────┼─────────────┘
                         ▼
                  Shared State
                  (Redis/Postgres)
```

## Security Layers

1. **Authentication**: Token-based gateway access
2. **Authorization**: Per-agent permission policies
3. **Isolation**: Docker sandbox containers
4. **Resource Limits**: CPU, memory, PID limits
5. **Network**: Default-deny network policy
6. **Filesystem**: Scoped, read-only mounts
7. **Secrets**: Vault-only credential access
