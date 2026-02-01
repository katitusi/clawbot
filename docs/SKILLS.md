# 🛠️ Skills Configuration Guide

## Overview

Skills are capabilities that agents can use to interact with the world. This guide covers recommended skills and their configuration.

## Skill Categories

### 🔑 Core / Infrastructure

#### `clawhub` (Required)

Package manager for skills.

```json
{
  "skills": {
    "config": {
      "clawhub": {
        "autoUpdate": true,
        "registry": "https://skills.openclaw.ai"
      }
    }
  }
}
```

**Commands:**
```bash
# Search skills
docker compose run --rm openclaw-cli skills search <query>

# Install skill
docker compose run --rm openclaw-cli skills install <skill-name>

# List installed
docker compose run --rm openclaw-cli skills list

# Update all
docker compose run --rm openclaw-cli skills update
```

#### `mcporter` (Highly Recommended)

Model Context Protocol adapter - connects to IDEs, databases, APIs.

```json
{
  "skills": {
    "config": {
      "mcporter": {
        "servers": [
          {
            "name": "filesystem",
            "transport": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
          },
          {
            "name": "github",
            "transport": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
              "GITHUB_TOKEN": "${GITHUB_TOKEN}"
            }
          }
        ]
      }
    }
  }
}
```

#### `model-usage`

Tracks token usage, latency, and costs.

```json
{
  "skills": {
    "config": {
      "model-usage": {
        "tracking": true,
        "alerts": {
          "dailyCost": 50,      // Alert at $50/day
          "monthlyBudget": 500  // Alert at $500/month
        }
      }
    }
  }
}
```

### 🧠 AI / Model Providers

#### `gemini`

Google Gemini adapter for fallback/multimodal.

```json
{
  "skills": {
    "config": {
      "gemini": {
        "model": "gemini-pro",
        "apiKey": "${GOOGLE_API_KEY}"
      }
    }
  }
}
```

#### `openai-whisper`

Local speech-to-text (requires ffmpeg).

```json
{
  "skills": {
    "config": {
      "openai-whisper": {
        "model": "base",     // tiny, base, small, medium, large
        "language": "en",
        "device": "cpu"      // cpu or cuda
      }
    }
  }
}
```

**Requirements:**
```dockerfile
# Add to Dockerfile
RUN apt-get install -y ffmpeg
```

### 🔐 Secrets Management

#### `1password`

Secure credential access via 1Password Connect.

```json
{
  "skills": {
    "config": {
      "1password": {
        "connectHost": "${OP_CONNECT_HOST}",
        "connectToken": "${OP_CONNECT_TOKEN}",
        "vault": "Production"
      }
    }
  }
}
```

**Setup:**
1. Install 1Password Connect server
2. Generate Connect token
3. Configure vault access

### 📧 Communication

#### `himalaya`

IMAP email client for agent email workflows.

```json
{
  "skills": {
    "config": {
      "himalaya": {
        "accounts": {
          "default": {
            "email": "agent@example.com",
            "backend": "imap",
            "imap": {
              "host": "imap.gmail.com",
              "port": 993,
              "ssl": true,
              "auth": {
                "type": "oauth2",
                "token": "${GMAIL_OAUTH_TOKEN}"
              }
            }
          }
        }
      }
    }
  }
}
```

**Use cases:**
- Email → Agent → Action workflows
- Auto-responses
- Email monitoring triggers

### 📝 Knowledge Management

#### `obsidian`

Knowledge base integration for self-documenting agents.

```json
{
  "skills": {
    "config": {
      "obsidian": {
        "vault": "~/.openclaw/workspace/knowledge",
        "features": {
          "create": true,
          "update": true,
          "search": true,
          "graph": true
        }
      }
    }
  }
}
```

**Use cases:**
- Self-documenting infrastructure
- AI second brain
- Runbook generation

## Skill Security

### Permission Levels

```json
{
  "skills": {
    "permissions": {
      "default": "sandboxed",
      "overrides": {
        "clawhub": "privileged",    // Needs host access
        "1password": "privileged",   // Needs vault access
        "himalaya": "network",       // Needs IMAP
        "obsidian": "filesystem"     // Needs vault folder
      }
    }
  }
}
```

### Sandbox Requirements by Skill

| Skill | Network | Filesystem | Privileged |
|-------|---------|------------|------------|
| clawhub | ✅ Yes | ✅ Read/Write | ❌ No |
| mcporter | Depends | ✅ Scoped | ❌ No |
| 1password | ✅ Yes | ❌ No | ❌ No |
| himalaya | ✅ Yes | ❌ No | ❌ No |
| obsidian | ❌ No | ✅ Vault only | ❌ No |
| openai-whisper | ❌ No | ✅ Temp | ❌ No |

## Recommended Configurations

### Development Setup

```json
{
  "skills": {
    "enabled": ["clawhub", "mcporter", "model-usage"],
    "autoInstall": ["clawhub", "mcporter"]
  },
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "docker": { "network": "bridge" }  // Allow network for dev
      }
    }
  }
}
```

### Production Setup

```json
{
  "skills": {
    "enabled": [
      "clawhub",
      "mcporter",
      "model-usage",
      "1password"
    ],
    "autoInstall": ["clawhub", "mcporter"]
  },
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",           // Sandbox everything
        "docker": { "network": "none" }  // No network default
      }
    }
  },
  "security": {
    "secrets": {
      "policy": "vault-only",
      "vault": "1password"
    }
  }
}
```

### Autonomous Research Agent

```json
{
  "agents": {
    "list": [
      {
        "id": "researcher",
        "name": "Research Agent",
        "model": "gpt-4o",
        "skills": ["mcporter", "obsidian", "himalaya"],
        "sandbox": {
          "mode": "non-main",
          "docker": {
            "network": "bridge",  // Needs web access
            "readOnlyRoot": true,
            "memory": "2g"
          }
        }
      }
    ]
  }
}
```

## Installing New Skills

```bash
# Interactive skill search
docker compose run --rm openclaw-cli skills search

# Install specific skill
docker compose run --rm openclaw-cli skills install himalaya

# Bulk install
docker compose run --rm openclaw-cli skills install clawhub mcporter model-usage

# Update configuration after install
# Edit ~/.openclaw/openclaw.json to configure the skill
```

## Troubleshooting

### Skill not found
```bash
# Update skill registry
docker compose run --rm openclaw-cli skills update

# Check available skills
docker compose run --rm openclaw-cli skills list --available
```

### Skill fails to execute
```bash
# Check sandbox logs
docker compose logs openclaw-gateway | grep "skill"

# Test skill manually
docker compose run --rm openclaw-cli skills test <skill-name>
```

### Permission denied
Check the skill's permission requirements and update `openclaw.json`:
```json
{
  "skills": {
    "permissions": {
      "overrides": {
        "failing-skill": "network"  // Grant network access
      }
    }
  }
}
```
