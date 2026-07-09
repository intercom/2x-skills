# Why Commands Require Approval

Claude Code asks for permission on potentially dangerous commands to protect against unintended consequences.

## Threat Categories

### Data Loss

Operations that permanently destroy data without recovery options. This includes file deletion, overwriting existing content, and resetting version control state. The damage is often irreversible.

### Secret Exposure

Commands that read sensitive files or output credentials. This includes accessing private keys, configuration files with API tokens, environment variables, and shell history. Once exposed in a session, secrets cannot be "unexposed."

### Remote Execution

Downloading and running code from external sources, or opening connections to remote systems. This creates pathways for arbitrary code execution and data exfiltration.

### Third-Party System Actions

Operations on cloud infrastructure, container orchestration, databases, or external APIs. These can affect production systems, incur costs, or impact other users.

### Privilege Escalation

Running commands with elevated privileges or as other users. This bypasses normal permission boundaries and can affect system-wide state.

---

## Defense Model

Even when trusting Claude, approval prompts protect against:

### Prompt Injection Attacks

Malicious content in files, websites, or user input could manipulate Claude into running dangerous commands. Approval prompts break this attack chain by requiring human verification.

### Misunderstanding Intent

Natural language is ambiguous. "Clean up the directory" could mean organizing files or deleting them. Approval ensures the intended action matches what will actually happen.

### Scope Creep

A simple fix might cascade into broader changes. Approval points provide checkpoints to verify scope before each potentially impactful operation.

### Unintended Side Effects

Commands can have non-obvious consequences beyond their primary purpose, such as running scripts during package installation or triggering CI pipelines on push.

---

## The Approval Tradeoff

**The cost:** A few extra keystrokes per session

**The benefit:** Protection against accidental data loss, secret exposure, infrastructure damage, runaway costs, and security breaches.

The small inconvenience of approving commands is worth the protection it provides.

---

## Recommended Approach

1. **Auto-allow read-only operations** - No risk, high frequency
2. **Consider auto-allowing development tools** - Sandboxed, predictable, frequent use
3. **Never auto-allow destructive or privileged operations** - Low frequency, high risk

The goal is reducing friction on safe operations while maintaining guardrails on dangerous ones.
