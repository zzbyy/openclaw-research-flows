#!/bin/bash
# install.sh — Research Wiki Installer
#
# Interactive setup that:
# 1. Asks where to create the vault (no defaults)
# 2. Asks where OpenClaw workspace is (no defaults)
# 3. Creates the vault from scratch
# 4. Installs the OpenClaw skill
# 5. Installs Python dependencies
# 6. Tells the user to run "setup" via chat to complete onboarding
#
# Usage: bash install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ask()   { echo -e "\n${CYAN}?${NC} $1"; }

# --- Welcome ---
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Research Wiki — Setup Installer      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "This will set up an automated research assistant that:"
echo "  - Scans papers daily and builds a knowledge wiki"
echo "  - Tracks researchers, citations, and topics"
echo "  - Sends you briefings via Telegram or Feishu"
echo ""
echo "You'll need:"
echo "  - Claude Code CLI installed (claude)"
echo "  - OpenClaw running with cc-bridge"
echo "  - Python 3.9+"
echo ""

# --- Check prerequisites ---
MISSING=()

if ! command -v claude &>/dev/null; then
    MISSING+=("claude — Install: https://claude.ai/claude-code")
fi
if ! command -v python3 &>/dev/null; then
    MISSING+=("python3 — Install: brew install python3")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    error "Missing prerequisites:"
    for m in "${MISSING[@]}"; do
        echo "  - $m"
    done
    echo ""
    echo "Install these first, then run this script again."
    exit 1
fi

# --- Ask for vault path ---
ask "Where should the research vault be created?"
echo "  This is a new folder that will hold your wiki, papers, and daily notes."
echo "  It can also be opened as an Obsidian vault."
echo ""
while true; do
    read -rp "  Path: " VAULT_DIR
    if [ -z "$VAULT_DIR" ]; then
        echo "  Please enter a path."
        continue
    fi
    # Expand tilde
    VAULT_DIR="${VAULT_DIR/#\~/$HOME}"
    # Resolve parent to absolute
    PARENT_DIR="$(cd "$(dirname "$VAULT_DIR")" 2>/dev/null && pwd 2>/dev/null)" || PARENT_DIR="$(dirname "$VAULT_DIR")"
    VAULT_DIR="$PARENT_DIR/$(basename "$VAULT_DIR")"

    if [ -d "$VAULT_DIR" ] && [ -f "$VAULT_DIR/CLAUDE.md" ]; then
        warn "A research vault already exists at $VAULT_DIR"
        read -rp "  Overwrite it? [y/N]: " overwrite
        if [[ ! "$overwrite" =~ ^[Yy] ]]; then
            echo "  Enter a different path."
            continue
        fi
    fi
    break
done

# --- Ask for OpenClaw workspace path ---
ask "Where is your OpenClaw workspace?"
echo "  This is typically ~/.openclaw/workspace or a custom path."
echo "  The research-wiki skill will be installed here."
echo ""

# Try to detect common locations
DETECTED_PATHS=()
for candidate in "$HOME/.openclaw/workspace" "$HOME/.openclaw"; do
    if [ -d "$candidate/skills" ]; then
        DETECTED_PATHS+=("$candidate")
    fi
done

if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
    echo "  Detected possible locations:"
    for i in "${!DETECTED_PATHS[@]}"; do
        echo "    [$((i+1))] ${DETECTED_PATHS[$i]}"
    done
    echo ""
fi

while true; do
    read -rp "  OpenClaw workspace path: " OC_WORKSPACE
    if [ -z "$OC_WORKSPACE" ]; then
        echo "  Please enter a path."
        continue
    fi
    OC_WORKSPACE="${OC_WORKSPACE/#\~/$HOME}"
    if [ ! -d "$OC_WORKSPACE" ]; then
        warn "$OC_WORKSPACE does not exist."
        read -rp "  Create it? [Y/n]: " create_it
        if [[ "$create_it" =~ ^[Nn] ]]; then
            continue
        fi
        mkdir -p "$OC_WORKSPACE/skills"
    fi
    break
done

SKILL_DEST="$OC_WORKSPACE/skills/research-wiki"

# --- Check for cc-bridge ---
CC_ENTRY=""
for candidate in \
    "$OC_WORKSPACE/skills/cc/scripts/cc-entry.sh" \
    "$HOME/.agents/skills/cc/scripts/cc-entry.sh" \
    "$HOME/.openclaw/workspace/skills/cc/scripts/cc-entry.sh"; do
    if [ -f "$candidate" ]; then
        CC_ENTRY="$candidate"
        break
    fi
done

if [ -z "$CC_ENTRY" ]; then
    warn "cc-bridge (cc-entry.sh) not found."
    echo "  The research wiki needs the OpenClaw cc-bridge to dispatch tasks."
    echo "  Install it from: https://github.com/zzbyy/openclaw-cc-bridge"
    echo ""
    read -rp "  Continue anyway? [y/N]: " cont
    if [[ ! "$cont" =~ ^[Yy] ]]; then
        exit 1
    fi
fi

# --- Create vault ---
echo ""
echo -e "${BOLD}Creating vault...${NC}"

mkdir -p "$VAULT_DIR"
cp -R "$SCRIPT_DIR/vault/"* "$VAULT_DIR/" 2>/dev/null || true
# Copy hidden files (like .gitkeep) but skip . and ..
for f in "$SCRIPT_DIR/vault/".*; do
    [ -f "$f" ] && cp "$f" "$VAULT_DIR/" 2>/dev/null || true
done
# Ensure directory structure exists (in case cp didn't create nested dirs)
mkdir -p "$VAULT_DIR/wiki/summaries" "$VAULT_DIR/wiki/entities" "$VAULT_DIR/wiki/concepts"
mkdir -p "$VAULT_DIR/wiki/synthesis/reviews" "$VAULT_DIR/wiki/synthesis/weekly"
mkdir -p "$VAULT_DIR/wiki/contradictions" "$VAULT_DIR/wiki/monitoring/reports"
mkdir -p "$VAULT_DIR/wiki/questions"
mkdir -p "$VAULT_DIR/raw/papers" "$VAULT_DIR/raw/clips" "$VAULT_DIR/raw/inbox"
mkdir -p "$VAULT_DIR/Daily Notes" "$VAULT_DIR/commands" "$VAULT_DIR/scripts"

chmod +x "$VAULT_DIR/scripts/"*.py 2>/dev/null || true

info "Vault created at $VAULT_DIR"

# --- Install skill ---
echo ""
echo -e "${BOLD}Installing OpenClaw skill...${NC}"

mkdir -p "$SKILL_DEST/scripts"
cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DEST/SKILL.md"
cp "$SCRIPT_DIR/skill/scripts/dispatch-research.sh" "$SKILL_DEST/scripts/dispatch-research.sh"
chmod +x "$SKILL_DEST/scripts/dispatch-research.sh"

# Configure vault path in dispatch script
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|__VAULT_DIR__|$VAULT_DIR|g" "$SKILL_DEST/scripts/dispatch-research.sh"
else
    sed -i "s|__VAULT_DIR__|$VAULT_DIR|g" "$SKILL_DEST/scripts/dispatch-research.sh"
fi

info "Skill installed at $SKILL_DEST"

# --- Install Python deps ---
echo ""
echo -e "${BOLD}Installing Python dependencies...${NC}"

if pip3 install -r "$VAULT_DIR/scripts/requirements.txt" --break-system-packages 2>/dev/null || \
   pip3 install -r "$VAULT_DIR/scripts/requirements.txt" 2>/dev/null; then
    info "Python packages installed (arxiv, requests, biopython)"
else
    warn "Automatic install failed. You may need to install manually:"
    echo "  pip3 install -r $VAULT_DIR/scripts/requirements.txt"
fi

# --- Done ---
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         Installation Complete!           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Vault:  $VAULT_DIR"
echo "  Skill:  $SKILL_DEST"
echo ""
echo -e "${BOLD}What to do next:${NC}"
echo ""
echo "  Open your Telegram or Feishu DM with your OpenClaw bot"
echo "  and send:"
echo ""
echo -e "    ${CYAN}setup${NC}"
echo ""
echo "  This starts an interactive wizard that walks you through:"
echo "    1. Your research field and keywords"
echo "    2. Which paper sources to enable (PubMed, arXiv, etc.)"
echo "    3. Researchers and papers to monitor"
echo "    4. Notification preferences"
echo "    5. Automated schedule (morning briefings, nightly batch, etc.)"
echo ""
echo "  The wizard handles everything — no need to edit files manually."
echo ""
echo -e "  ${BOLD}Documentation:${NC} $SCRIPT_DIR/docs/"
echo "    ARCHITECTURE.md — how the system works"
echo "    WORKFLOWS.md    — what each command does"
echo "    AGENT-GUIDE.md  — troubleshooting"
echo ""
