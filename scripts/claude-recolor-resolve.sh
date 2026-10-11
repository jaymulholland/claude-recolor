#!/usr/bin/env bash
# Deterministic path for "/recolor <spec>": resolves named presets/hexes/rainbow,
# derives the palette with palette.pl (real math, not LLM reasoning), edits the
# variables in an already-installed ~/.local/bin/claude-recolor, and runs it.
#
# This exists so the common case -- a known preset name, a hex, or "rainbow" --
# never has to reread CLAUDE-CODE-RECOLOR.md or re-derive colour math in an LLM
# turn. It only knows how to update EXISTING variables in the installed script;
# it does not do first-time install or structural multi-group engineering --
# both of those still need an agent following CLAUDE-CODE-RECOLOR.md.
#
# Usage:
#   claude-recolor-resolve.sh [--show] [--script PATH] SPEC
#
# SPEC is 1-3 comma-separated phrases, each one of:
#   - a 6-digit hex, with or without '#'
#   - a known preset name (case-insensitive) from presets.txt / presets-neutral.txt,
#     or from the user's ~/.config/claude-recolor/presets.txt / dedicated.txt
#   - the literal word "rainbow"
#
# One phrase sets ACCENT (auto mode). Two or three phrases require the
# installed script to already define ACCENT_TAB/ACCENT_FIELD (a prior custom
# install) -- this tool never invents that structure itself.
#
# Exit codes:
#   0  applied
#   2  a phrase didn't resolve to a known preset/hex/rainbow -- caller (the
#      agent) should turn it into a hex itself (description -> colour needs
#      real language understanding) and re-invoke with that hex instead
#   3  phrase count doesn't match what the installed script supports
#   1  other error (script not installed, bad input, etc.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED="$HOME/.local/bin/claude-recolor"
SHOW_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --show) SHOW_ONLY=1; shift ;;
    --script) INSTALLED="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

if [[ "$SHOW_ONLY" == 1 ]]; then
  [[ -f "$INSTALLED" ]] || { echo "claude-recolor-resolve: not installed at $INSTALLED" >&2; exit 1; }
  grep -E '^(ACCENT|ACCENT_DARK|ACCENT_SOFT|ACCENT_BG|ACCENT_TAB|ACCENT_FIELD|DONE_DOT|RAINBOW|RAINBOW_COLOURS|RAINBOW_SECS|MODE_COLOURS)=' "$INSTALLED"
  exit 0
fi

SPEC="${1:-}"
[[ -n "$SPEC" ]] || { echo "usage: claude-recolor-resolve.sh [--show] [--script PATH] SPEC" >&2; exit 1; }
[[ -f "$INSTALLED" ]] || { echo "claude-recolor-resolve: not installed at $INSTALLED -- run the full recipe first" >&2; exit 1; }

# --- split SPEC on commas into 1-3 trimmed phrases ---------------------------
IFS=',' read -ra RAW_PHRASES <<< "$SPEC"
PHRASES=()
for p in "${RAW_PHRASES[@]}"; do
  p="$(echo "$p" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -n "$p" ]] && PHRASES+=("$p")
done
COUNT=${#PHRASES[@]}
if (( COUNT < 1 || COUNT > 3 )); then
  echo "claude-recolor-resolve: expected 1-3 comma-separated phrases, got $COUNT" >&2
  exit 1
fi

# --- preset lookup ------------------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-recolor"
PRESET_FILES=("$SCRIPT_DIR/presets.txt" "$CONFIG_DIR/presets.txt" "$CONFIG_DIR/dedicated.txt")
NEUTRAL_FILE="$SCRIPT_DIR/presets-neutral.txt"

norm_name() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' -'; }

lookup_preset() {
  local want
  want="$(norm_name "$1")"
  local f line name hex
  for f in "${PRESET_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS='|' read -r name hex _rest; do
      [[ -z "$name" || "$name" == \#* ]] && continue
      if [[ "$(norm_name "$name")" == "$want" ]]; then
        echo "$hex"
        return 0
      fi
    done < "$f"
  done
  return 1
}

lookup_neutral() {
  local want
  want="$(norm_name "$1")"
  [[ -f "$NEUTRAL_FILE" ]] || return 1
  local name a d s b
  while IFS='|' read -r name a d s b; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    if [[ "$(norm_name "$name")" == "$want" ]]; then
      echo "$a|$d|$s|$b"
      return 0
    fi
  done < "$NEUTRAL_FILE"
  return 1
}

is_hex() { [[ "$1" =~ ^#?[0-9A-Fa-f]{6}$ ]]; }
norm_hex() { local h="$1"; [[ "$h" == \#* ]] || h="#$h"; echo "${h^^}"; }

# Resolved[i] is either "HEX:#RRGGBB", "NEUTRAL:a|d|s|b", or "RAINBOW"
RESOLVED=()
for phrase in "${PHRASES[@]}"; do
  if [[ "$(norm_name "$phrase")" == "rainbow" ]]; then
    RESOLVED+=("RAINBOW")
  elif is_hex "$phrase"; then
    RESOLVED+=("HEX:$(norm_hex "$phrase")")
  elif hex="$(lookup_preset "$phrase")"; then
    RESOLVED+=("HEX:$(norm_hex "$hex")")
  elif n="$(lookup_neutral "$phrase")"; then
    RESOLVED+=("NEUTRAL:$n")
  else
    echo "UNRESOLVED: $phrase" >&2
    echo "claude-recolor-resolve: not a known preset, hex, or 'rainbow' -- resolve '$phrase' to a hex (or ask the user) and re-invoke with that hex in its place" >&2
    exit 2
  fi
done

# --- map phrases to script variables, matching what's already installed -----
has_var() { grep -qE "^$1=" "$INSTALLED"; }

declare -A TARGET   # var name -> resolved entry
case "$COUNT" in
  1)
    TARGET[ACCENT]="${RESOLVED[0]}"
    ;;
  2)
    if ! has_var ACCENT_FIELD; then
      echo "claude-recolor-resolve: '$INSTALLED' is auto-mode (single ACCENT) -- it has no separate text-field variable yet. Follow CLAUDE-CODE-RECOLOR.md's custom-install steps once to add ACCENT_FIELD, then this tool can update it." >&2
      exit 3
    fi
    TARGET[ACCENT]="${RESOLVED[0]}"        # tab icon + chat content
    TARGET[ACCENT_FIELD]="${RESOLVED[1]}"  # text field
    ;;
  3)
    if ! has_var ACCENT_TAB || ! has_var ACCENT_FIELD; then
      echo "claude-recolor-resolve: '$INSTALLED' doesn't have separate tab-icon/text-field variables yet -- follow CLAUDE-CODE-RECOLOR.md's custom-install steps once first." >&2
      exit 3
    fi
    TARGET[ACCENT_TAB]="${RESOLVED[0]}"
    TARGET[ACCENT]="${RESOLVED[1]}"
    TARGET[ACCENT_FIELD]="${RESOLVED[2]}"
    ;;
esac

# --- apply one resolved entry to one variable, deriving palette where needed -
set_var() {
  local var="$1" val="$2"
  perl -pi -e "s/^\\Q$var\\E=.*/$var=\"$val\"/" "$INSTALLED"
}

RAINBOW_REQUESTED=0
for var in "${!TARGET[@]}"; do
  entry="${TARGET[$var]}"
  case "$entry" in
    RAINBOW)
      RAINBOW_REQUESTED=1
      # Caller still picks RAINBOW_COLOURS/RAINBOW_SECS by hand if non-default;
      # this tool just flips the switch and leaves a sane static ACCENT fallback.
      set_var RAINBOW 1
      ;;
    HEX:*)
      hex="${entry#HEX:}"
      set_var "$var" "$hex"
      if [[ "$var" == "ACCENT" ]]; then
        eval "$(perl "$SCRIPT_DIR/palette.pl" "$hex" | sed 's/^/derived_/')"
        set_var ACCENT_DARK "$derived_ACCENT_DARK"
        set_var ACCENT_SOFT "$derived_ACCENT_SOFT"
        set_var ACCENT_BG "$derived_ACCENT_BG"
        set_var DONE_DOT "$derived_DONE_DOT"
        [[ "$RAINBOW_REQUESTED" == 0 ]] && set_var RAINBOW 0
      fi
      ;;
    NEUTRAL:*)
      IFS='|' read -r a d s b <<< "${entry#NEUTRAL:}"
      set_var "$var" "$a"
      if [[ "$var" == "ACCENT" ]]; then
        set_var ACCENT_DARK "$d"
        set_var ACCENT_SOFT "$s"
        set_var ACCENT_BG "$b"
        [[ "$RAINBOW_REQUESTED" == 0 ]] && set_var RAINBOW 0
      fi
      ;;
  esac
done

echo "claude-recolor-resolve: applied -- $(grep -E '^(ACCENT|ACCENT_DARK|ACCENT_SOFT|ACCENT_BG|ACCENT_TAB|ACCENT_FIELD|DONE_DOT|RAINBOW)=' "$INSTALLED" | tr '\n' ' ')"
"$INSTALLED"
