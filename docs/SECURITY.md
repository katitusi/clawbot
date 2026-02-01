# 🔒 Security Best Practices

## Overview

AI agents with tool access are inherently risky. This document outlines security measures implemented in this deployment and recommendations for production use.

## Threat Model

### What can go wrong?

1. **Credential Leakage**: Agent exposes API keys or secrets
2. **Filesystem Access**: Agent reads/writes unauthorized files
3. **Network Exfiltration**: Agent sends data to external servers
4. **Command Injection**: Malicious commands executed on host
5. **Resource Exhaustion**: Agent consumes all CPU/memory
6. **Privilege Escalation**: Container escape to host

## Security Layers

### 1. Gateway Authentication

```bash
# Generate strong token
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
```

**Best Practices:**
- Use tokens ≥64 characters (256 bits)
- Rotate tokens regularly
- Never commit tokens to version control
- Use different tokens per environment

### 2. Network Isolation

```yaml
# docker-compose.yml
ports:
  # Bind to localhost only (recommended)
  - "127.0.0.1:18789:18789"
  # NOT this (exposes to network):
  # - "18789:18789"
```

**For external access:**
- Use SSH tunnel: `ssh -L 18789:127.0.0.1:18789 user@server`
- Or reverse proxy with authentication (nginx + auth)

### 3. Sandbox Isolation

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",
        "docker": {
          // Read-only root filesystem
          "readOnlyRoot": true,
          
          // No network by default
          "network": "none",
          
          // Drop all capabilities
          "capDrop": ["ALL"],
          
          // Resource limits
          "pidsLimit": 256,
          "memory": "1g",
          "memorySwap": "2g",
          "cpus": 1,
          
          // Non-root user
          "user": "1000:1000",
          
          // Temporary filesystems
          "tmpfs": ["/tmp", "/var/tmp", "/run"]
        }
      }
    }
  }
}
```

### 4. Filesystem Scoping

```json
{
  "security": {
    "filesystem": {
      "policy": "scoped",
      "allowedPaths": [
        "~/.openclaw/workspace"
      ],
      "deniedPaths": [
        "~/.ssh",
        "~/.gnupg",
        "~/.aws",
        "~/.config",
        "/etc",
        "/root"
      ]
    }
  }
}
```

### 5. Secrets Management

**DON'T do this:**
```bash
# Bad: secrets in environment
export OPENAI_API_KEY=sk-xxx
```

**DO this:**
```json
{
  "security": {
    "secrets": {
      "policy": "vault-only",
      "vault": "1password"
    }
  }
}
```

Or use Docker secrets:
```yaml
services:
  openclaw-gateway:
    secrets:
      - openai_api_key
      
secrets:
  openai_api_key:
    file: ./secrets/openai_api_key.txt
```

### 6. Command Restrictions

```json
{
  "security": {
    "shell": {
      "policy": "sandboxed",
      "deniedCommands": [
        "rm -rf",
        "sudo",
        "chmod 777",
        "curl | bash",
        "wget | sh"
      ],
      "deniedPatterns": [
        ".*\\|.*sh$",
        ".*>.*\\/etc\\/.*"
      ]
    }
  }
}
```

## Docker Security Hardening

### Container Security Options

```yaml
services:
  openclaw-gateway:
    security_opt:
      - no-new-privileges:true
      - seccomp:./seccomp-profile.json
      # - apparmor:openclaw-profile
    
    cap_drop:
      - ALL
    cap_add:
      # Only if absolutely needed
      # - NET_BIND_SERVICE
```

### Seccomp Profile

Create `seccomp-profile.json`:
```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close",
        "stat", "fstat", "lstat",
        "poll", "lseek", "mmap", "mprotect",
        "munmap", "brk", "ioctl",
        "access", "pipe", "select",
        "sched_yield", "mremap", "msync",
        "mincore", "madvise", "shmget",
        "shmat", "shmctl", "dup", "dup2",
        "pause", "nanosleep", "getitimer",
        "alarm", "setitimer", "getpid"
        // ... add more as needed
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

## Monitoring & Auditing

### Log Analysis

```bash
# Monitor gateway logs
docker compose logs -f openclaw-gateway | grep -E "(ERROR|WARN|security)"

# Check for suspicious activity
grep -E "(rm -rf|sudo|chmod|curl.*\\|)" ~/.openclaw/logs/*.log
```

### Resource Monitoring

```bash
# Container stats
docker stats openclaw-gateway

# Check resource limits
docker inspect openclaw-gateway | jq '.[0].HostConfig.Memory'
```

### Audit Trail

Enable comprehensive logging:
```json
{
  "logging": {
    "level": "info",
    "auditEvents": [
      "skill.execute",
      "file.access",
      "network.request",
      "auth.attempt"
    ]
  }
}
```

## Incident Response

### If credentials are exposed:

1. **Immediately rotate** the exposed credential
2. **Check audit logs** for unauthorized access
3. **Review agent sessions** for suspicious activity
4. **Update security policy** to prevent recurrence

### If container is compromised:

1. **Stop the container**: `docker compose down`
2. **Preserve evidence**: `docker commit openclaw-gateway compromised-image`
3. **Analyze**: `docker run -it compromised-image /bin/sh`
4. **Rebuild from clean image**: `docker compose build --no-cache`

## Checklist

### Before Production:

- [ ] Generated strong gateway token (≥64 chars)
- [ ] Configured localhost-only port binding
- [ ] Enabled sandbox mode for all agents
- [ ] Set up secrets management (1password/vault)
- [ ] Configured filesystem scoping
- [ ] Added resource limits to all containers
- [ ] Enabled audit logging
- [ ] Set up log monitoring/alerting
- [ ] Tested backup and recovery
- [ ] Documented incident response procedure

### Regular Maintenance:

- [ ] Rotate gateway token (monthly)
- [ ] Review audit logs (weekly)
- [ ] Update Docker images (weekly)
- [ ] Test backup restoration (monthly)
- [ ] Review security policy (quarterly)
