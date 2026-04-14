# OpenClaw → Claude Code Integration

Configure OpenClaw to route research commands to Claude Code sessions.

---

## Architecture

```
You (Telegram/Slack)
        ↓
   OpenClaw Gateway
        ↓ (pattern match)
   Claude Code Session
        ↓ (reads CLAUDE.md)
   Execute Workflow
        ↓
   Update wiki/
        ↓
   Report back to OpenClaw
        ↓
You (notification)
```

---

## OpenClaw Skill Configuration

Create `~/.openclaw/skills/research-wiki/skill.yaml`:

```yaml
name: research-wiki
description: Route research commands to Claude Code for wiki maintenance
version: 1.0.0

triggers:
  # Ingest commands
  - pattern: "ingest (.+)"
    action: claude_code
    command: "/ingest $1"
    
  - pattern: "(process|add) (this )?(paper|pdf|article)( .+)?"
    action: claude_code
    command: "/ingest raw/inbox/"
    
  # Batch processing
  - pattern: "batch( process)? ?(\\d+)? ?(papers?)?"
    action: claude_code
    command: "/batch raw/papers ${2:-10}"
    
  - pattern: "process (my )?(inbox|downloads)"
    action: claude_code
    command: "/batch raw/inbox --all"
    
  # Queries
  - pattern: "(what do I know about|search wiki for|find papers on) (.+)"
    action: claude_code
    command: "/query $2"
    
  - pattern: "(compare|contrast) (.+) (and|vs|with) (.+)"
    action: claude_code
    command: "/query Compare $2 and $4"
    
  # Synthesis
  - pattern: "(synthesize|summarize|review) (.+)"
    action: claude_code
    command: "/synthesis $2"
    
  # Maintenance
  - pattern: "lint( the wiki)?"
    action: claude_code
    command: "/lint --fix"
    
  - pattern: "(wiki )?(stats|status|health)"
    action: claude_code
    command: "/stats"
    
  # Competitor tracking
  - pattern: "(check|track|monitor) (papers by |from )?(.+)"
    action: claude_code
    command: "/compete $3"

claude_code:
  working_directory: "/path/to/your/vault"
  model: "opus-4.6"
  auto_approve: true  # For file operations
  timeout: 300        # 5 minutes max per session
```

---

## Routing Logic

Add to OpenClaw's main config (`~/.openclaw/OPENCLAW.md`):

```markdown
## Research Wiki Routing

When I receive a message that matches research patterns, spawn a Claude Code session:

### Spawn Command
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "[extracted command]" \
       --auto-approve \
       --timeout 300
```

### Pattern → Command Mapping

| User says | Extracted command |
|-----------|-------------------|
| "ingest raw/inbox/paper.pdf" | `/ingest raw/inbox/paper.pdf` |
| "process this paper" | `/ingest raw/inbox/` |
| "batch 10 papers" | `/batch raw/papers 10` |
| "process my inbox" | `/batch raw/inbox --all` |
| "what do I know about attention?" | `/query attention mechanisms` |
| "compare BERT and GPT" | `/query Compare BERT and GPT` |
| "synthesize transformers" | `/synthesis transformers` |
| "lint the wiki" | `/lint --fix` |
| "wiki stats" | `/stats` |
| "check papers by Vaswani" | `/compete Vaswani` |

### Response Handling

1. Capture Claude Code stdout
2. Parse for status indicators:
   - ✅ = success
   - ⚠️ = warning
   - ❌ = error
3. Relay to user via same channel
4. If error, offer retry or manual intervention
```

---

## Heartbeat Triggers

Add scheduled Claude Code sessions to `HEARTBEAT.md`:

```markdown
## Daily: 7:00 AM — Morning Briefing
```bash
claude --directory /path/to/vault \
       --message "/search-arxiv" \
       --auto-approve
```
Then relay results to Telegram.

## Daily: 9:00 PM — Background Processing
```bash
claude --directory /path/to/vault \
       --message "/batch raw/inbox --all && /batch --continue 5" \
       --auto-approve
```
Silent unless errors.

## Weekly: Sunday 6:00 PM — Maintenance
```bash
claude --directory /path/to/vault \
       --message "/lint --fix --deep" \
       --auto-approve
```
Relay summary to Telegram.
```

---

## Session Startup Sequence

When Claude Code starts in the vault:

1. **Auto-read CLAUDE.md** (Claude Code does this automatically)
2. **Parse incoming command** from OpenClaw message
3. **Load relevant workflow** from `commands/[command].md`
4. **Execute steps**
5. **Report results** in OpenClaw-friendly format

### Ensuring CLAUDE.md is Read

Claude Code automatically reads `CLAUDE.md` in the working directory. Ensure your vault root contains:

```
vault/
├── CLAUDE.md           # ← Main instructions (required)
├── commands/           # ← Detailed workflows
│   ├── ingest.md
│   ├── batch.md
│   ├── lint.md
│   └── ...
├── raw/
├── wiki/
└── ...
```

---

## Example Flow

**You send** (via Telegram):
```
ingest raw/inbox/attention-paper.pdf
```

**OpenClaw**:
1. Pattern matches "ingest (.+)"
2. Extracts path: `raw/inbox/attention-paper.pdf`
3. Spawns Claude Code:
```bash
claude --model opus-4.6 \
       --directory ~/vault \
       --message "/ingest raw/inbox/attention-paper.pdf" \
       --auto-approve
```

**Claude Code**:
1. Reads CLAUDE.md
2. Sees `/ingest` command
3. Reads `commands/ingest.md`
4. Executes workflow:
   - Extracts PDF content
   - Creates summary
   - Updates entities
   - Updates index and log
5. Outputs:
```
✅ Ingested: Attention Is All You Need
📄 Summary: [[wiki/summaries/20260413-attention-is-all-you-need]]
👤 Entities: 8 created (Vaswani, Shazeer, ...)
🔗 Relationships: 12 added
```

**OpenClaw**:
1. Captures output
2. Relays to Telegram:
```
✅ Ingested: Attention Is All You Need
📄 wiki/summaries/20260413-attention-is-all-you-need
👤 8 new entities
🔗 12 relationships added
```

---

## Advanced: Chained Commands

For complex workflows, chain commands:

```bash
# Process inbox then generate weekly summary
claude --message "/batch raw/inbox --all && /synthesis this-week"

# Full maintenance cycle
claude --message "/lint --fix && /stats && /batch --continue 5"
```

---

## Error Handling

If Claude Code session fails:

```markdown
## Error Recovery

1. **Timeout**: Session took >5 minutes
   - Relay: "⏱️ Session timed out. Try a smaller batch?"
   - Log error for review

2. **File Error**: Can't read/write
   - Relay: "❌ File error: [details]"
   - Suggest: "Check permissions on vault directory"

3. **Model Error**: API issue
   - Relay: "⚠️ Temporary issue. Retrying in 60s..."
   - Auto-retry once

4. **Unknown Command**: Pattern not matched
   - Relay: "🤔 Not sure what you mean. Try:
     - 'ingest [path]'
     - 'batch [count] papers'
     - 'what do I know about [topic]?'
     - 'lint the wiki'"
```

---

## Monitoring

Track session health:

```markdown
# wiki/session-log.md

## [YYYY-MM-DD HH:MM] Session: /ingest
Trigger: Telegram message
Duration: 45s
Status: success
Output: [summary]

## [YYYY-MM-DD HH:MM] Session: /batch
Trigger: Heartbeat
Duration: 180s
Status: partial (3/5 succeeded)
Output: [details]
Errors: [error log]
```

Query with: "show recent sessions" → scans session-log.md
