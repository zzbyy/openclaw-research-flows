#!/bin/bash
# install.sh — Research Wiki Installer
#
# One-command install:
#   curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-research-flows/main/install.sh | bash
#
# Interactive prompts work even when piped (reads from /dev/tty).
# Friendly for non-technical users — numbered choices, clear descriptions.

set -e

REPO_URL="https://github.com/zzbyy/openclaw-research-flows.git"
REPO_NAME="openclaw-research-flows"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
step()  { echo -e "\n${BOLD}$1${NC}"; }

# Read from /dev/tty so interactive prompts work even via curl|bash
prompt() {
    local var_name="$1"
    local message="$2"
    local default="$3"
    local value

    if [ -n "$default" ]; then
        echo -ne "  ${CYAN}?${NC} ${message} ${DIM}[${default}]${NC}: " >&2
    else
        echo -ne "  ${CYAN}?${NC} ${message}: " >&2
    fi
    read -r value < /dev/tty
    value="${value:-$default}"
    eval "$var_name='$value'"
}

choose() {
    local var_name="$1"
    shift
    local options=("$@")

    for i in "${!options[@]}"; do
        echo -e "  ${BOLD}$((i+1))${NC}  ${options[$i]}" >&2
    done
    echo "" >&2

    local choice
    echo -ne "  ${CYAN}?${NC} Enter number: " >&2
    read -r choice < /dev/tty

    # Validate
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        eval "$var_name='$((choice-1))'"
    else
        eval "$var_name='0'"
    fi
}

# =============================================
# Welcome
# =============================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      Research Wiki — Setup Installer         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Automated research assistant that scans papers, builds a"
echo "  knowledge wiki, and sends you daily briefings."
echo ""

# =============================================
# Step 1: Prerequisites
# =============================================
step "Step 1/5 — Checking your system..."

READY=true

if command -v git &>/dev/null; then
    info "git"
else
    fail "git — run: xcode-select --install"
    READY=false
fi

if command -v python3 &>/dev/null; then
    info "python3 ($(python3 --version 2>&1 | awk '{print $2}'))"
else
    fail "python3 — run: brew install python3"
    READY=false
fi

if command -v claude &>/dev/null; then
    info "claude (Claude Code CLI)"
else
    fail "claude — install from https://claude.ai/claude-code"
    READY=false
fi

# Find OpenClaw config
OC_CONFIG="$HOME/.openclaw/openclaw.json"
if [ -f "$OC_CONFIG" ]; then
    info "OpenClaw config found"
else
    fail "OpenClaw not found (~/.openclaw/openclaw.json missing)"
    READY=false
fi

if ! $READY; then
    echo ""
    echo "  Fix the items marked with ✗ above, then run this installer again."
    exit 1
fi

# =============================================
# Step 2: Download repo
# =============================================
step "Step 2/5 — Getting research-flows..."

SCRIPT_DIR=""

if [ -f "vault/CLAUDE.md" ] && [ -f "skill/SKILL.md" ]; then
    SCRIPT_DIR="$(pwd)"
    info "Using local repo: $SCRIPT_DIR"
elif [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/vault/CLAUDE.md" ] 2>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    info "Using local repo: $SCRIPT_DIR"
else
    CLONE_DIR="$HOME/$REPO_NAME"
    if [ -d "$CLONE_DIR/.git" ]; then
        git -C "$CLONE_DIR" pull --quiet 2>/dev/null || true
        info "Updated: $CLONE_DIR"
    else
        git clone --quiet "$REPO_URL" "$CLONE_DIR"
        info "Downloaded to $CLONE_DIR"
    fi
    SCRIPT_DIR="$CLONE_DIR"
fi

if [ ! -f "$SCRIPT_DIR/vault/CLAUDE.md" ]; then
    fail "Repo files missing at $SCRIPT_DIR"
    exit 1
fi

# =============================================
# Step 3: Vault location
# =============================================
step "Step 3/5 — Where should your research vault live?"
echo ""
echo "  The vault is a folder with your wiki, papers, and daily notes."
echo "  You can also open it as an Obsidian vault."
echo ""

# Check for existing vaults (look for CLAUDE.md with our marker)
EXISTING_VAULTS=()
for candidate in "$HOME/research-vault" "$HOME/ObVaults/"*/; do
    if [ -f "$candidate/CLAUDE.md" ] && grep -q "Research Wiki" "$candidate/CLAUDE.md" 2>/dev/null; then
        EXISTING_VAULTS+=("$candidate")
    fi
done

if [ ${#EXISTING_VAULTS[@]} -gt 0 ]; then
    echo "  Found existing vault(s):"
    VAULT_OPTIONS=()
    for v in "${EXISTING_VAULTS[@]}"; do
        VAULT_OPTIONS+=("Use existing: $v")
    done
    VAULT_OPTIONS+=("Create new vault")
    choose VAULT_CHOICE "${VAULT_OPTIONS[@]}"

    if [ "$VAULT_CHOICE" -lt "${#EXISTING_VAULTS[@]}" ]; then
        VAULT_DIR="${EXISTING_VAULTS[$VAULT_CHOICE]}"
        VAULT_DIR="${VAULT_DIR%/}"
        info "Using existing vault: $VAULT_DIR"
    else
        # Ask for new vault path with validation loop
        while true; do
            prompt VAULT_DIR "Path for new vault" "$HOME/research-vault"
            VAULT_DIR="${VAULT_DIR/#\~/$HOME}"
            PARENT="$(dirname "$VAULT_DIR")"
            if [ -d "$PARENT" ] || mkdir -p "$PARENT" 2>/dev/null; then
                break
            fi
            warn "Cannot create directory at that path. Check for typos and try again."
            echo "  (Parent directory $PARENT does not exist or is not writable.)"
            echo ""
        done
    fi
else
    echo "  Where should the vault be created?"
    echo ""
    # Ask with validation loop
    while true; do
        prompt VAULT_DIR "Vault path" "$HOME/research-vault"
        VAULT_DIR="${VAULT_DIR/#\~/$HOME}"
        PARENT="$(dirname "$VAULT_DIR")"
        if [ -d "$PARENT" ] || mkdir -p "$PARENT" 2>/dev/null; then
            break
        fi
        warn "Cannot create directory at that path. Check for typos and try again."
        echo "  (Parent directory $PARENT does not exist or is not writable.)"
        echo ""
    done
fi

# Resolve to absolute path with correct case (macOS is case-insensitive
# so /users/zz works but we need /Users/zz in the stored path)
mkdir -p "$VAULT_DIR"
VAULT_DIR="$(cd "$VAULT_DIR" && pwd -P)"
cp -R "$SCRIPT_DIR/vault/"* "$VAULT_DIR/" 2>/dev/null || true
for f in "$SCRIPT_DIR/vault/".*; do
    [ -f "$f" ] && cp "$f" "$VAULT_DIR/" 2>/dev/null || true
done
mkdir -p "$VAULT_DIR/wiki/summaries" "$VAULT_DIR/wiki/entities" "$VAULT_DIR/wiki/concepts"
mkdir -p "$VAULT_DIR/wiki/synthesis/reviews" "$VAULT_DIR/wiki/synthesis/weekly"
mkdir -p "$VAULT_DIR/wiki/contradictions" "$VAULT_DIR/wiki/monitoring/reports"
mkdir -p "$VAULT_DIR/wiki/questions"
mkdir -p "$VAULT_DIR/raw/papers" "$VAULT_DIR/raw/clips" "$VAULT_DIR/raw/inbox"
mkdir -p "$VAULT_DIR/Daily Notes" "$VAULT_DIR/commands" "$VAULT_DIR/scripts"
chmod +x "$VAULT_DIR/scripts/"*.py 2>/dev/null || true

info "Vault ready at $VAULT_DIR"

# =============================================
# Step 4: Install skill
# =============================================
step "Step 4/5 — Which agent should get the research-wiki skill?"
echo ""

# Read agents from openclaw.json: defaults.workspace + list[]
AGENT_INFO=$(python3 -c "
import json, os, sys
try:
    with open(os.path.expanduser('~/.openclaw/openclaw.json')) as f:
        cfg = json.load(f)
    agents = cfg.get('agents', {})
    default_ws = agents.get('defaults', {}).get('workspace', os.path.expanduser('~/.openclaw/workspace'))
    # Output: id|workspace per line. First line is always the global default.
    print('__global__|' + default_ws)
    for agent in agents.get('list', []):
        aid = agent.get('id', '')
        ws = agent.get('workspace', default_ws)
        if aid:
            print(aid + '|' + ws)
except Exception as e:
    print('__error__|' + str(e), file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

if [ -z "$AGENT_INFO" ]; then
    # Fallback if python parsing fails
    GLOBAL_WORKSPACE="$HOME/.openclaw/workspace"
    AGENT_INFO="__global__|$GLOBAL_WORKSPACE"
    warn "Could not read agents from openclaw.json, using default workspace"
fi

# Parse into arrays
AGENT_IDS=()
AGENT_WORKSPACES=()
while IFS='|' read -r aid aws; do
    AGENT_IDS+=("$aid")
    AGENT_WORKSPACES+=("$aws")
done <<< "$AGENT_INFO"

# Build choices
CHOICES=()
for i in "${!AGENT_IDS[@]}"; do
    aid="${AGENT_IDS[$i]}"
    aws="${AGENT_WORKSPACES[$i]}"
    if [ "$aid" = "__global__" ]; then
        CHOICES+=("All agents (global) — ${aws}/skills/")
    else
        CHOICES+=("Agent \"$aid\" — ${aws}/skills/")
    fi
done

choose INSTALL_CHOICE "${CHOICES[@]}"

CHOSEN_WORKSPACE="${AGENT_WORKSPACES[$INSTALL_CHOICE]}"
CHOSEN_AGENT="${AGENT_IDS[$INSTALL_CHOICE]}"
SKILL_DEST="$CHOSEN_WORKSPACE/skills/research-wiki"

mkdir -p "$SKILL_DEST/scripts"
cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DEST/SKILL.md"
cp "$SCRIPT_DIR/skill/scripts/dispatch-research.sh" "$SKILL_DEST/scripts/dispatch-research.sh"
chmod +x "$SKILL_DEST/scripts/dispatch-research.sh"

# Wire vault path into dispatch script
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|__VAULT_DIR__|$VAULT_DIR|g" "$SKILL_DEST/scripts/dispatch-research.sh"
else
    sed -i "s|__VAULT_DIR__|$VAULT_DIR|g" "$SKILL_DEST/scripts/dispatch-research.sh"
fi

if [ "$CHOSEN_AGENT" = "__global__" ]; then
    info "Skill installed globally at $SKILL_DEST"
else
    info "Skill installed for agent \"$CHOSEN_AGENT\" at $SKILL_DEST"
fi

# =============================================
# Step 5: Python dependencies
# =============================================
step "Step 5/5 — Installing Python packages..."

if pip3 install -r "$VAULT_DIR/scripts/requirements.txt" --break-system-packages -q 2>/dev/null || \
   pip3 install -r "$VAULT_DIR/scripts/requirements.txt" -q 2>/dev/null; then
    info "Installed: arxiv, requests, biopython"
else
    warn "Auto-install failed. Run manually:"
    echo "    pip3 install arxiv requests biopython"
fi

# =============================================
# Done
# =============================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║            Installation Complete!            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Vault : $VAULT_DIR"
echo "  Skill : $SKILL_DEST"
echo "  Docs  : $SCRIPT_DIR/docs/"
echo ""
echo -e "  ${BOLD}Next step:${NC}"
echo ""
echo "  Open your Telegram or Feishu DM with your OpenClaw bot"
echo "  and send:"
echo ""
echo -e "        ${CYAN}${BOLD}/rw setup${NC}"
echo ""
echo "  The bot will walk you through everything:"
echo "    → Your research field and keywords"
echo "    → Which paper sources to use (PubMed, arXiv, etc.)"
echo "    → Researchers and papers to monitor"
echo "    → Notification preferences"
echo "    → Automated schedule"
echo ""
