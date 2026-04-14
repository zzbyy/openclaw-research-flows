#!/bin/bash
# dispatch-research.sh — Route research wiki commands to Claude Code via cc-bridge
#
# This is a thin wrapper around the cc-bridge's cc-entry.sh that:
# 1. Hardcodes the vault directory (set during install)
# 2. Passes --topic for group chat notification routing
# 3. Delegates everything else to the existing cc-bridge infrastructure
#
# Usage:
#   dispatch-research.sh "<command>"
#   dispatch-research.sh --topic 42 "<command>"
#
# Examples:
#   dispatch-research.sh "/briefing"
#   dispatch-research.sh --topic 50 "/ingest raw/inbox/paper.pdf"
#   dispatch-research.sh "/batch raw/papers 10"

set -e

# === CONFIGURATION ===
# Set this to your vault's absolute path during installation.
# The install.sh script will replace this placeholder automatically.
VAULT_DIR="__VAULT_DIR__"

# Path to the cc-bridge entry script
CC_ENTRY="${CC_ENTRY:-$HOME/.agents/skills/cc/scripts/cc-entry.sh}"

# Fallback: try the workspace skills path
if [ ! -f "$CC_ENTRY" ]; then
    CC_ENTRY="$HOME/.openclaw/workspace/skills/cc/scripts/cc-entry.sh"
fi

# === VALIDATION ===
if [ ! -f "$CC_ENTRY" ]; then
    echo '{"error": "cc-bridge not found. Install openclaw-cc-bridge first.", "checked": ["~/.agents/skills/cc/scripts/cc-entry.sh", "~/.openclaw/workspace/skills/cc/scripts/cc-entry.sh"]}'
    exit 1
fi

if [ "$VAULT_DIR" = "__VAULT_DIR__" ]; then
    echo '{"error": "VAULT_DIR not configured. Run install.sh or set VAULT_DIR in this script."}'
    exit 1
fi

if [ ! -d "$VAULT_DIR" ]; then
    echo "{\"error\": \"Vault directory not found: $VAULT_DIR\"}"
    exit 1
fi

# === PARSE ARGUMENTS ===
TOPIC_ARGS=()
if [ "$1" = "--topic" ]; then
    TOPIC_ARGS=(--topic "$2")
    shift 2
fi

COMMAND="$*"

if [ -z "$COMMAND" ]; then
    echo '{"error": "No command provided. Usage: dispatch-research.sh [--topic N] \"<command>\""}'
    exit 1
fi

# === DISPATCH ===
# cc-entry.sh expects: [--topic N] <directory> <prompt>
exec "$CC_ENTRY" "${TOPIC_ARGS[@]}" "$VAULT_DIR" "$COMMAND"
