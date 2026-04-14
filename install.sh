#!/bin/bash
# install.sh — Research Wiki One-Click Installer
#
# One-command install (no questions asked):
#   curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-research-flows/main/install.sh | bash
#
# The script is fully non-interactive:
# 1. Clones the repo (if not already present)
# 2. Auto-detects OpenClaw workspace
# 3. Creates vault at ~/research-vault
# 4. Installs skill, Python deps
# 5. Tells user to send "setup" in chat for onboarding
#
# All configuration happens in the chat onboarding wizard — not here.

set -e

REPO_URL="https://github.com/zzbyy/openclaw-research-flows.git"
REPO_NAME="openclaw-research-flows"
VAULT_DIR="$HOME/research-vault"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
step()  { echo -e "\n${BOLD}$1${NC}"; }

# =============================================
# Welcome
# =============================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      Research Wiki — One-Click Install       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# =============================================
# Step 1: Check prerequisites
# =============================================
step "Step 1/5 — Checking prerequisites..."

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

# Auto-detect OpenClaw workspace
OC_WORKSPACE=""
for candidate in "$HOME/.openclaw/workspace" "$HOME/.openclaw"; do
    if [ -d "$candidate/skills" ]; then
        OC_WORKSPACE="$candidate"
        break
    fi
done

if [ -n "$OC_WORKSPACE" ]; then
    info "OpenClaw workspace: $OC_WORKSPACE"
else
    fail "OpenClaw workspace not found (checked ~/.openclaw/workspace, ~/.openclaw)"
    echo ""
    echo "  Make sure OpenClaw is installed and has been started at least once."
    echo "  Then run this installer again."
    READY=false
fi

# Check cc-bridge
CC_FOUND=false
for candidate in \
    "$OC_WORKSPACE/skills/cc/scripts/cc-entry.sh" \
    "$HOME/.agents/skills/cc/scripts/cc-entry.sh" \
    "$HOME/.openclaw/workspace/skills/cc/scripts/cc-entry.sh"; do
    if [ -f "$candidate" ]; then
        CC_FOUND=true
        info "cc-bridge: $candidate"
        break
    fi
done

if ! $CC_FOUND; then
    warn "cc-bridge not found — install from https://github.com/zzbyy/openclaw-cc-bridge"
    echo "  (You can install it later, but the research wiki won't work without it.)"
fi

if ! $READY; then
    echo ""
    echo "Fix the items marked with ✗ above, then run this installer again."
    exit 1
fi

# =============================================
# Step 2: Download repo
# =============================================
step "Step 2/5 — Getting research-flows..."

SCRIPT_DIR=""

# Are we already inside the repo?
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
        info "Updated existing repo: $CLONE_DIR"
    else
        git clone --quiet "$REPO_URL" "$CLONE_DIR"
        info "Cloned to $CLONE_DIR"
    fi
    SCRIPT_DIR="$CLONE_DIR"
fi

if [ ! -f "$SCRIPT_DIR/vault/CLAUDE.md" ]; then
    fail "Repo files missing at $SCRIPT_DIR"
    exit 1
fi

# =============================================
# Step 3: Create vault
# =============================================
step "Step 3/5 — Creating vault at $VAULT_DIR..."

mkdir -p "$VAULT_DIR"
cp -R "$SCRIPT_DIR/vault/"* "$VAULT_DIR/" 2>/dev/null || true
for f in "$SCRIPT_DIR/vault/".*; do
    [ -f "$f" ] && cp "$f" "$VAULT_DIR/" 2>/dev/null || true
done

# Ensure all directories exist
mkdir -p "$VAULT_DIR/wiki/summaries" "$VAULT_DIR/wiki/entities" "$VAULT_DIR/wiki/concepts"
mkdir -p "$VAULT_DIR/wiki/synthesis/reviews" "$VAULT_DIR/wiki/synthesis/weekly"
mkdir -p "$VAULT_DIR/wiki/contradictions" "$VAULT_DIR/wiki/monitoring/reports"
mkdir -p "$VAULT_DIR/wiki/questions"
mkdir -p "$VAULT_DIR/raw/papers" "$VAULT_DIR/raw/clips" "$VAULT_DIR/raw/inbox"
mkdir -p "$VAULT_DIR/Daily Notes" "$VAULT_DIR/commands" "$VAULT_DIR/scripts"
chmod +x "$VAULT_DIR/scripts/"*.py 2>/dev/null || true

info "Vault ready"

# =============================================
# Step 4: Install OpenClaw skill
# =============================================
step "Step 4/5 — Installing OpenClaw skill..."

SKILL_DEST="$OC_WORKSPACE/skills/research-wiki"
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

info "Skill installed at $SKILL_DEST"

# =============================================
# Step 5: Install Python dependencies
# =============================================
step "Step 5/5 — Installing Python packages..."

if pip3 install -r "$VAULT_DIR/scripts/requirements.txt" --break-system-packages -q 2>/dev/null || \
   pip3 install -r "$VAULT_DIR/scripts/requirements.txt" -q 2>/dev/null; then
    info "Installed: arxiv, requests, biopython"
else
    warn "Auto-install failed. Run manually:"
    echo "  pip3 install -r $VAULT_DIR/scripts/requirements.txt"
fi

# =============================================
# Done!
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
echo -e "${BOLD}Next step:${NC}"
echo ""
echo "  Open your Telegram or Feishu DM with your OpenClaw bot"
echo "  and send:"
echo ""
echo -e "        ${CYAN}${BOLD}setup${NC}"
echo ""
echo "  The bot will walk you through everything:"
echo "    → Your research field and keywords"
echo "    → Which paper sources to use (PubMed, arXiv, etc.)"
echo "    → Researchers and papers to monitor"
echo "    → Notification preferences"
echo "    → Automated schedule (briefings, batch processing, etc.)"
echo ""
echo "  No files to edit. The wizard handles it all."
echo ""
