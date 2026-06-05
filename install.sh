#!/usr/bin/env bash
# SANS-AI-Hackathon install script
# Preflight requirement: protocol-sift install.sh must have been run first.
# Usage: curl -fsSL https://raw.githubusercontent.com/bscsanschang/SANS-AI-Hackathon/main/install.sh | bash
#    or: bash install.sh   (from a local clone)
set -euo pipefail

REPO_URL="https://github.com/bscsanschang/SANS-AI-Hackathon.git"
TMPDIR_PREFIX="sans-ai-hackathon-install"
PROTOCOL_SIFT_INSTALL_CMD="curl -fsSL https://raw.githubusercontent.com/teamdfir/protocol-sift/main/install.sh | bash"

# -- helpers -----------------------------------------------------------------

info() { printf '\033[1;34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m  %s\n' "$*" >&2; exit 1; }

die_protocol_sift() {
    printf '\033[1;31m[fail]\033[0m  %s\n' "Preflight failed. protocol-sift does not appear to be installed." >&2
    cat >&2 <<EOF_MSG

Install protocol-sift first:
  ${PROTOCOL_SIFT_INSTALL_CMD}

Then re-run this installer.
EOF_MSG
    exit 1
}

backup_if_exists() {
    local target="$1"
    local bak
    local stamp
    local i

    if [[ -e "$target" ]]; then
        stamp="$(date +%Y%m%d%H%M%S)"
        bak="${target}.bak-${stamp}"
        i=1
        while [[ -e "$bak" ]]; do
            bak="${target}.bak-${stamp}.${i}"
            i=$((i + 1))
        done
        mv "$target" "$bak"
        warn "Backed up existing $(basename "$target") -> $bak"
    fi
}

require_repo_file() {
    local path="$1"
    local display_path="${path#"$REPO_DIR"/}"

    [[ -f "$path" ]] || die "Required repository file missing: $display_path"
}

copy_file() {
    local src="$1"
    local dst="$2"
    local display_src="${src#"$REPO_DIR"/}"

    cp "$src" "$dst" || die "Failed to copy $display_src to $dst"
}

cleanup() {
    if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

# -- preflight: verify protocol-sift was installed ---------------------------

info "SANS-AI-Hackathon - DFIR Claude Code overlay installer"
echo

[[ -n "${HOME:-}" ]] || die "HOME is not set; cannot locate ~/.claude."
CLAUDE_DIR="${HOME}/.claude"

info "Checking preflight requirement: protocol-sift..."

# This installer is only an overlay. It must not create ~/.claude from scratch.
if [[ ! -d "$CLAUDE_DIR" ]]; then
    warn "Missing Claude directory: $CLAUDE_DIR"
    die_protocol_sift
fi

PREFLIGHT_OK=1

# protocol-sift installs its global CLAUDE.md and settings.json into ~/.claude
# and places skills into ~/.claude/skills/. We check for a combination of these
# sentinel files that should exist after a successful protocol-sift installation.
REQUIRED_PROTOCOL_SIFT_FILES=(
    "${CLAUDE_DIR}/CLAUDE.md"
    "${CLAUDE_DIR}/settings.json"
    "${CLAUDE_DIR}/skills/memory-analysis/SKILL.md"
    "${CLAUDE_DIR}/skills/plaso-timeline/SKILL.md"
    "${CLAUDE_DIR}/skills/sleuthkit/SKILL.md"
    "${CLAUDE_DIR}/skills/windows-artifacts/SKILL.md"
    "${CLAUDE_DIR}/skills/yara-hunting/SKILL.md"
    "${CLAUDE_DIR}/analysis-scripts/generate_pdf_report.py"
)

for sentinel in "${REQUIRED_PROTOCOL_SIFT_FILES[@]}"; do
    if [[ ! -f "$sentinel" ]]; then
        warn "Missing protocol-sift file: $sentinel"
        PREFLIGHT_OK=0
    fi
done

if [[ "$PREFLIGHT_OK" -ne 1 ]]; then
    echo >&2
    die_protocol_sift
fi

ok "protocol-sift installation verified."
echo

# -- locate repo files --------------------------------------------------------

# When this script is run as `curl ... | bash`, Bash is reading from stdin and
# BASH_SOURCE[0] is empty. In that mode there is no local script directory, so
# force the clone path instead of accidentally treating the caller's PWD as the
# repository root.
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd -P)"
fi

WORK_DIR=""
if [[ -n "$SCRIPT_DIR" && \
      -f "$SCRIPT_DIR/Claude Directory/CLAUDE.md" && \
      -f "$SCRIPT_DIR/Claude Directory/settings.json" ]]; then
    info "Running from local repo/archive - skipping clone."
    REPO_DIR="$SCRIPT_DIR"
else
    command -v git >/dev/null 2>&1 || die "git is required but not found. Install git and retry."

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${TMPDIR_PREFIX}.XXXXXX")" || die "Failed to create a temporary directory."
    info "Cloning SANS-AI-Hackathon into temp directory..."
    git clone --depth=1 --quiet "$REPO_URL" "$WORK_DIR/repo" || die "Failed to clone $REPO_URL."
    REPO_DIR="$WORK_DIR/repo"
    ok "Clone complete."
fi
echo

# -- verify expected repository layout ---------------------------------------

SCRIPTS=(
    run_logged.sh
    audit_command_ledger.py
    pdf_visual_check.py
    validate_claims.py
)

HOOKS=(
    enforce-run-logged.sh
)

require_repo_file "$REPO_DIR/Claude Directory/CLAUDE.md"
require_repo_file "$REPO_DIR/Claude Directory/settings.json"

for script in "${SCRIPTS[@]}"; do
    require_repo_file "$REPO_DIR/Claude Directory/scripts/$script"
done

for hook in "${HOOKS[@]}"; do
    require_repo_file "$REPO_DIR/Claude Directory/hooks/$hook"
done

require_repo_file "$REPO_DIR/Case Directory/CLAUDE.md"

# -- global config overlay ----------------------------------------------------
# This repo ships its own CLAUDE.md and settings.json that extend/replace the
# protocol-sift versions for the SANS AI Hackathon workflow.

info "Installing global config overlay..."

for f in CLAUDE.md settings.json; do
    src="$REPO_DIR/Claude Directory/$f"
    dst="$CLAUDE_DIR/$f"
    backup_if_exists "$dst"
    copy_file "$src" "$dst"
    ok "Claude Directory/$f -> $dst"
done
echo

# -- scripts -----------------------------------------------------------------
# The repo ships several helper scripts into ~/.claude/scripts/.

info "Installing scripts..."
mkdir -p "$CLAUDE_DIR/scripts"
for script in "${SCRIPTS[@]}"; do
    src="$REPO_DIR/Claude Directory/scripts/$script"
    dst="$CLAUDE_DIR/scripts/$script"
    copy_file "$src" "$dst"
    # Make shell scripts executable.
    [[ "$script" == *.sh ]] && chmod +x "$dst"
    ok "scripts/$script -> $dst"
done
echo

# -- hooks -------------------------------------------------------------------

info "Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "${HOOKS[@]}"; do
    src="$REPO_DIR/Claude Directory/hooks/$hook"
    dst="$CLAUDE_DIR/hooks/$hook"
    copy_file "$src" "$dst"
    chmod +x "$dst"
    ok "hooks/$hook -> $dst"
done
echo

# -- case template ------------------------------------------------------------
# The Case Directory CLAUDE.md is a per-case template that analysts copy into
# each new case directory and customize. We store it in ~/.claude/case-templates/
# alongside the protocol-sift case template for easy reference.

info "Installing case template..."
mkdir -p "$CLAUDE_DIR/case-templates"
src="$REPO_DIR/Case Directory/CLAUDE.md"
dst="$CLAUDE_DIR/case-templates/CLAUDE.md.sans-ai-hackathon"
copy_file "$src" "$dst"
ok "Case Directory/CLAUDE.md -> $dst"
echo

# -- done --------------------------------------------------------------------

ok "Installation complete."
cat <<'EOF_MSG'

-- Next steps -------------------------------------------------------------

  1. Create a new case directory:

     export CASE=MY-CASE-2025-001
     mkdir -p /cases/${CASE}/{analysis,exports,reports,logs}
     cp ${HOME}/.claude/case-templates/CLAUDE.md.sans-ai-hackathon \
        /cases/${CASE}/CLAUDE.md
     nano /cases/${CASE}/CLAUDE.md   # fill in case details

  2. Move evidence into the case directory, then mount it:

     sudo mkdir -p /mnt/ewf_evidence /mnt/evidence
     sudo ewfmount <evidenceFile> /mnt/ewf_evidence
     OFFSET=$(sudo mmls /mnt/ewf_evidence/ewf1 | awk '/NTFS/{print $3; exit}')
     sudo mount -o ro,loop,noatime,offset=$((OFFSET*512)) \
          /mnt/ewf_evidence/ewf1 /mnt/evidence

  3. Open Claude Code from the case directory:

     cd /cases/${CASE} && claude

  4. Issue a triage command, for example:

     find evil in <evidenceFile> and write a PDF report

  Note: Do NOT copy ~/.claude/.credentials.json - it contains your API key.
-------------------------------------------------------------------------
EOF_MSG