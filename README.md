# Research Wiki — OpenClaw + Claude Code

An automated research assistant that builds a compounding knowledge base from academic papers. Uses OpenClaw as the messaging/scheduling layer and Claude Code (Opus 4.6) as the execution engine, backed by an Obsidian vault.

## What It Does

- **Daily Briefings** — Scans PubMed, arXiv, and Semantic Scholar every morning, scores papers against your research context, auto-ingests the most relevant ones, and generates a daily note
- **Paper Ingestion** — Processes PDFs into structured wiki summaries with entities, relationships, confidence scores, and contradiction detection
- **Literature Monitoring** — Tracks specific researchers, citation networks, and emerging topics; generates alerts and literature reviews
- **Wiki Maintenance** — Finds orphan pages, broken links, stale claims; auto-fixes what it can; flags the rest for human review

## Architecture

```
You (Telegram DM / Feishu)
        ↓
   OpenClaw Gateway
        ↓ (pattern match via SKILL.md)
   dispatch-research.sh → cc-bridge → Claude Code (Opus 4.6)
        ↓ (reads CLAUDE.md, runs workflow)
   Obsidian Vault (wiki/, raw/, Daily Notes/)
        ↓ (hooks send results back)
   You (notification in DM)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full data flow.

## Prerequisites

- **OpenClaw** with Telegram or Feishu bot configured
- **[openclaw-cc-bridge](https://github.com/zzbyy/openclaw-cc-bridge)** installed
- **Claude Code CLI** (`claude`)
- **Python 3.9+** with pip

## Quick Start

### Step 1: Install (one command, no questions)

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-research-flows/main/install.sh | bash
```

The script runs silently — no questions asked. It:
- Checks prerequisites (git, python3, claude, OpenClaw)
- Clones the repo to `~/openclaw-research-flows`
- Creates a vault at `~/research-vault`
- Auto-detects your OpenClaw workspace and installs the skill
- Installs Python packages (arxiv, requests, biopython)

### Step 2: Send "setup" in chat

Open your **Telegram DM** or **Feishu DM** with your OpenClaw bot and send:

```
setup
```

This starts an interactive wizard that walks you through:
1. Your research field and keywords
2. Which paper sources to enable (PubMed, arXiv, Semantic Scholar)
3. Researchers and papers to monitor
4. Notification preferences
5. Automated schedule (morning briefings, nightly batch, etc.)

No need to edit config files manually — the wizard handles everything.

### Step 3: You're done

Your first briefing will arrive at the time you chose. Drop PDFs into `raw/inbox/` anytime — they'll be processed automatically.

## Commands

Send these via Telegram DM or Feishu to your OpenClaw bot:

| Command | What it does |
|---------|-------------|
| `setup` | First-time configuration wizard |
| `briefing` | Morning research briefing with auto-ingest |
| `ingest [path]` | Process a single paper into the wiki |
| `batch [N] papers` | Batch-process N papers |
| `process inbox` | Process all papers in raw/inbox/ |
| `query [topic]` | Search the wiki and synthesize an answer |
| `synthesize [topic]` | Generate a topic synthesis |
| `monitor` | Run full literature monitoring cycle |
| `track researcher [name]` | Start tracking a researcher |
| `review [topic]` | Generate a literature review |
| `find gaps` | Analyze knowledge gaps |
| `lint` | Wiki health check and auto-fix |
| `stats` | Wiki statistics |
| `triage` | Show papers awaiting review |
| `set up schedule` | Configure or change automated jobs |

## Project Structure

```
openclaw-research-flows/
├── vault/                  # Vault template (copied to target during install)
│   ├── CLAUDE.md           # Master instructions for Claude Code
│   ├── commands/           # Workflow definitions
│   │   ├── ingest.md       #   Single paper processing
│   │   ├── batch.md        #   Multi-paper batch processing
│   │   ├── briefing.md     #   Daily research briefing
│   │   ├── monitor.md      #   Literature monitoring & reviews
│   │   ├── lint.md         #   Wiki health check
│   │   └── onboard.md      #   Interactive setup wizard
│   ├── scripts/            # Python API helpers
│   │   ├── search_arxiv.py
│   │   ├── search_semantic_scholar.py
│   │   ├── search_pubmed.py
│   │   └── download_paper.py
│   └── wiki/               # Initial wiki structure
│
├── skill/                  # OpenClaw skill (installed to your workspace)
│   ├── SKILL.md            # Command routing rules
│   └── scripts/
│       └── dispatch-research.sh
│
├── docs/                   # Documentation
│   ├── ARCHITECTURE.md     # System architecture & data flow
│   ├── WORKFLOWS.md        # All workflow descriptions
│   ├── AGENT-GUIDE.md      # How Claude Code sessions work
│   ├── HEARTBEAT.md        # Cron schedule reference
│   └── CONFIGURATION.md    # Configuration guide
│
├── install.sh              # Interactive installer
└── README.md               # This file
```

## Documentation

| Doc | What's in it |
|-----|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System overview, component responsibilities, data flow diagrams |
| [WORKFLOWS.md](docs/WORKFLOWS.md) | Every workflow step-by-step: triggers, inputs, outputs, wiki updates |
| [AGENT-GUIDE.md](docs/AGENT-GUIDE.md) | How Claude Code sessions work, how scripts are called, troubleshooting |
| [HEARTBEAT.md](docs/HEARTBEAT.md) | Full cron schedule reference |
| [CONFIGURATION.md](docs/CONFIGURATION.md) | How to configure research context, monitoring, scoring, notifications |

## Design Docs (Reference)

The original design specifications that this implementation is based on:

| File | Description |
|------|-------------|
| `CLAUDE-wiki-complete.md` | Original CLAUDE.md specification |
| `briefing.md` | Briefing workflow specification |
| `ingest.md` | Ingest workflow specification |
| `batch.md` | Batch workflow specification |
| `monitor.md` | Monitoring workflow specification |
| `lint.md` | Lint workflow specification |
| `HEARTBEAT-complete.md` | Original heartbeat schedule |
| `openclaw-claudecode-routing.md` | Routing architecture |
| `monitoring-config-template.md` | Monitoring config template |
