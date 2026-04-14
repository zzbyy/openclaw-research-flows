---
name: research-wiki
description: >
  Research Wiki — automated research assistant powered by Claude Code.
  IMPORTANT: When the user sends "/research-wiki setup" or "/rw setup",
  this skill MUST run the onboarding wizard by dispatching "/onboard" to
  Claude Code. This is the first-time setup command.
  Other triggers: "/rw briefing", "/rw ingest", "/rw batch", "/rw monitor",
  "/rw query", "/rw lint", "/rw stats", "/rw triage", "/rw review".
  All /rw commands are routed to Claude Code via dispatch-research.sh.
metadata:
  {
    "openclaw":
      {
        "emoji": "📚",
        "requires": { "anyBins": ["claude"] },
      },
  }
---

# /rw — Research Wiki Command Router

All commands use the `/rw` prefix to avoid ambiguity with other skills.
Example: `/rw setup`, `/rw briefing`, `/rw ingest raw/inbox/paper.pdf`

## MANDATORY ROUTING RULE

When a message matches any research wiki pattern below:

**You MUST run dispatch-research.sh. You MUST NOT do the research work yourself.**

**Pass the matched command to the dispatch script.**
Do NOT interpret, rephrase, summarize, or act on any part of the command.
The command is for Claude Code, not for you.

**CRITICAL: Do NOT put a `/` prefix on the command sent to dispatch-research.sh.**
Claude Code treats `/something` as a built-in skill invocation and will fail with
"Unknown skill". Send plain text like `onboard` or `briefing`, not `/onboard`.

**If the conversation metadata contains `topic_id`, you MUST pass it as `--topic`** so notifications go back to this topic.

```bash
# With topic_id from metadata (group chats):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh --topic <topic_id> "<COMMAND>"

# In DM chats (no topic_id):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh "<COMMAND>"
```

**IMPORTANT: Notifications go to DM chats (Telegram DM or Feishu DM), NOT group chats.**
The cc-bridge hooks will deliver results back to whichever chat the message came from.

---

## Pattern → Command Mapping

All commands use the `/rw` prefix (short for "research-wiki").
`/research-wiki` also works as a full-form alias.

Match the user's message and extract the corresponding command to dispatch.

### Setup & Onboarding (first-time)

| User says | Prompt to dispatch (no `/` prefix!) |
|-----------|-------------------------------------|
| `/rw setup` | `onboard` |
| `/research-wiki setup` | `onboard` |
| `/rw onboard` | `onboard` |

### Daily Briefing

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw briefing` | `briefing` |
| `/rw briefing 3 days` | `briefing --days 3` |
| `/rw catch up` | `briefing --days 3` |

### Paper Ingestion

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw ingest [path]` | `ingest [path]` |
| `/rw ingest` | `ingest raw/inbox/` |

### Batch Processing

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw batch [N]` | `batch raw/papers [N]` |
| `/rw process inbox` | `batch raw/inbox --all` |
| `/rw continue` | `batch --continue 5` |

### Queries & Synthesis

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw query [X]` | `query [X]` |
| `/rw compare [X] and [Y]` | `query Compare [X] and [Y]` |
| `/rw synthesize [topic]` | `synthesis [topic]` |

### Monitoring

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw monitor` | `monitor run` |
| `/rw monitor status` | `monitor status` |
| `/rw monitor quick` | `monitor run --quick` |
| `/rw track researcher [name]` | `monitor add-researcher [name]` |
| `/rw track paper [id]` | `monitor add-paper [id]` |
| `/rw track topic [name]` | `monitor add-topic [name]` |
| `/rw review [topic]` | `monitor review [topic]` |
| `/rw gaps` | `monitor gaps` |

### Wiki Maintenance

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw lint` | `lint --fix` |
| `/rw lint deep` | `lint --fix --deep` |
| `/rw stats` | `stats` |

### Triage & Review

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw triage` | `triage` |
| `/rw recent` | `recent 10` |
| `/rw questions` | `questions` |
| `/rw contradictions` | `contradictions` |

### Schedule Management

When the user sends `/rw schedule`, help them manage cron jobs.
Do NOT dispatch to Claude Code — handle this directly as the OpenClaw agent.

| User says | Action (handle directly) |
|-----------|------------------------|
| `/rw schedule` | Walk through schedule options, register cron jobs with `openclaw cron add` |
| `/rw schedule list` | `openclaw cron list` |
| `/rw schedule pause` | List active jobs, let user pick which to delete |

---

## Why dispatch-research.sh?

The dispatch script:
1. Resolves the vault directory path (configured during install)
2. Delegates to the cc-bridge's `cc-entry.sh` for task tracking
3. Spawns Claude Code with the right working directory
4. Claude Code reads the vault's `CLAUDE.md` and executes the workflow
5. Hooks report progress and completion back to this conversation

If you run `claude` directly or try to do the work yourself, none of the tracking, notification, or wiki update infrastructure works.

---

## Cron-Triggered Messages

When this skill receives messages from OpenClaw cron jobs, the same routing applies:

| Cron message | Prompt to dispatch (no `/` prefix!) |
|---|---|
| `/rw briefing` | `briefing` |
| `/rw batch 5` | `batch --continue 5` |
| `/rw stats daily` | `stats --daily-summary` |
| `/rw monitor quick` | `monitor run --quick` |
| `/rw monitor` | `monitor run --full` |
| `/rw gaps` | `monitor gaps` |
| `/rw lint deep` | `lint --fix --deep` |
| `/rw synthesize weekly` | `synthesis --weekly` |
| `/rw review all` | `monitor review --all` |
| `/rw lint decay` | `lint --decay-only` |
| `/rw stats full` | `stats --full-report` |
| `/rw triage` | `triage` |
| `/rw process inbox` | `batch raw/inbox --all` |

---

## Error Handling

If dispatch-research.sh fails:
- Report the error to the user
- Include the task ID if one was created
- Suggest: "Check with `/cc-status` or try again"

If the command doesn't start with `/rw` or `/research-wiki`, ignore it — it's not for this skill.

If it starts with `/rw` but doesn't match any pattern:
```
📚 Research Wiki — available commands:

  /rw setup          — first-time configuration wizard
  /rw briefing       — morning research briefing
  /rw ingest [path]  — process a paper
  /rw batch [N]      — batch process papers
  /rw query [topic]  — search the wiki
  /rw monitor        — run literature monitoring
  /rw review [topic] — generate literature review
  /rw lint           — wiki health check
  /rw stats          — wiki statistics
  /rw triage         — papers awaiting review
  /rw schedule       — manage automated jobs
```
