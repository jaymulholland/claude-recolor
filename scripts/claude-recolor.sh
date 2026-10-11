#!/usr/bin/env bash
# Recolour the Claude Code VS Code extension (brand orange -> your accent).
# Safe to re-run: already-patched versions are skipped. Always patches from the
# saved originals, so changing a colour below and re-running applies cleanly.
# Restore a version: copy *.bak / .orig-resources/* back over the patched files.
#
# Variables below are edited in place by claude-recolor-resolve (or by hand) --
# don't change the logic below that line without updating both copies: this
# file and the matching heredoc in CLAUDE-CODE-RECOLOR.md.
set -euo pipefail

ACCENT="#5B9CF6"       # replaces brand orange #D97757 (logo, mascot, highlights)
ACCENT_DARK="#3B7BE0"  # replaces clay button orange #C6613F (filled buttons)
ACCENT_SOFT="#93BDF8"  # replaces Jupyter banner text orange #F5A66A
ACCENT_BG="#1F2A3F"    # replaces Jupyter banner background brown #3F2A1F
DONE_DOT="#22C55E"     # tab icon "finished" dot; must differ from ACCENT and the blue "working" dot
CUSTOM_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/claude-recolor/custom.css"  # optional, appended to the panel CSS
RAINBOW=0              # 1 = animated rainbow gradient on top of ACCENT (ACCENT stays as the reduced-motion fallback)
RAINBOW_COLOURS=("#FF4D4D" "#FF9F1A" "#FFE03B" "#4ADE80" "#3B9BFF" "#A66BFF")
RAINBOW_SECS=6         # one full trip through the colours
MODE_COLOURS=0         # 1 = also make Plan/Auto-accept-edits/Auto/Bypass-permissions match ACCENT_DARK; 0 leaves them on VS Code's own theme tokens (Anthropic's built-in safety colours, see "Permission-mode colours")

# Every VS Code-family extensions folder that exists gets patched
EXT_ROOTS=(
  "$HOME/.vscode/extensions"
  "$HOME/.vscode-insiders/extensions"
  "$HOME/.cursor/extensions"
  "$HOME/.windsurf/extensions"
)

STAMP=".recolor-stamp"
custom_sum=""
[[ -f "$CUSTOM_CSS" ]] && custom_sum="$(cksum < "$CUSTOM_CSS")"
WANT="$ACCENT $ACCENT_DARK $ACCENT_SOFT $ACCENT_BG $DONE_DOT $custom_sum rainbow=$RAINBOW ${RAINBOW_COLOURS[*]} $RAINBOW_SECS mode_colours=$MODE_COLOURS"

# perl -pi works the same on Linux and macOS (sed -i does not)
sub() { perl -pi -e "$1" "${@:2}"; }

# Rainbow pieces, built once from RAINBOW_COLOURS (first colour repeated at the end so the loop is seamless)
if [[ "$RAINBOW" == 1 ]]; then
  loop=("${RAINBOW_COLOURS[@]}" "${RAINBOW_COLOURS[0]}")
  n=$(( ${#loop[@]} - 1 ))
  stops="" bands=""
  for i in "${!loop[@]}"; do
    stops+="<stop offset=\"$(awk "BEGIN{print $i/$n}")\" stop-color=\"${loop[$i]}\"/>"
    bands+="${bands:+, }${loop[$i]} $(( i * 40 ))px"
  done
  # SVG gradient that slides sideways forever; fills reference it as url(#rcRainbow)
  export RC_DEFS="<defs><linearGradient id=\"rcRainbow\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\" spreadMethod=\"repeat\">$stops<animateTransform attributeName=\"gradientTransform\" type=\"translate\" from=\"0 0\" to=\"1 0\" dur=\"${RAINBOW_SECS}s\" repeatCount=\"indefinite\"/></linearGradient></defs>"
  # Only these few elements animate directly, each on its own background-position.
  # Earlier versions instead registered --app-claude-orange as an animated custom
  # property inherited by ~28 descendants (every border, focus ring and tint that
  # reads it) -- elegant, but it forced Chromium to recompute style for all of them
  # every frame, which froze VS Code outright on at least one Windows machine.
  # Scoping the animation to a handful of concrete elements avoids that; borders,
  # rings and tints stay a solid ACCENT instead of cycling.
  RAINBOW_CSS="
/* claude-recolor rainbow */
@keyframes rc-slide { to { background-position: $(( n * 40 ))px 0; } }
@media (prefers-reduced-motion: no-preference) {
  [class^=\"brand_\"], [class*=\" brand_\"], [class^=\"orbChar_\"], [class*=\" orbChar_\"],
  [class^=\"worktreeBannerButton_\"], [class*=\" worktreeBannerButton_\"],
  [class^=\"usageFillHigh_\"], [class*=\" usageFillHigh_\"], [class^=\"orbDot_\"], [class*=\" orbDot_\"] {
    background-image: repeating-linear-gradient(90deg, $bands);
    background-size: $(( n * 40 ))px 100%;
    animation: rc-slide ${RAINBOW_SECS}s linear infinite;
  }
  [class^=\"brand_\"], [class*=\" brand_\"], [class^=\"orbChar_\"], [class*=\" orbChar_\"] {
    -webkit-background-clip: text; background-clip: text; color: transparent;
  }
}
"
  # Inline panel SVGs (mascot) need the gradient defined somewhere in the page
  RAINBOW_JS=";(()=>{const a=()=>{if(document.getElementById(\"rcRainbowDefs\"))return;document.body.insertAdjacentHTML(\"beforeend\",'<svg id=\"rcRainbowDefs\" width=\"0\" height=\"0\" style=\"position:absolute\" aria-hidden=\"true\">$RC_DEFS</svg>')};document.body?a():document.addEventListener(\"DOMContentLoaded\",a)})();"
fi

shopt -s nullglob
for root in "${EXT_ROOTS[@]}"; do
  for dir in "$root"/anthropic.claude-code-*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    # Skip versions VS Code has marked for deletion
    if [[ -f "$root/.obsolete" ]] && grep -q "\"$name\"" "$root/.obsolete"; then
      continue
    fi
    [[ -f "$dir/$STAMP" && "$(cat "$dir/$STAMP")" == "$WANT" ]] && continue

    css="$dir/webview/index.css"
    js="$dir/webview/index.js"
    res="$dir/resources"
    # Extension may still be unpacking; the watcher will fire again later
    [[ -f "$css" && -f "$js" && -d "$res" ]] || continue

    # Back up originals once
    [[ -f "$css.bak" ]] || cp "$css" "$css.bak"
    [[ -f "$js.bak" ]] || cp "$js" "$js.bak"
    if [[ ! -d "$dir/.orig-resources" ]]; then
      mkdir -p "$dir/.orig-resources"
      cp "$res"/*.svg "$dir/.orig-resources/"
    fi

    cp "$css.bak" "$css"
    cp "$js.bak" "$js"
    cp "$dir/.orig-resources/"*.svg "$res/"

    # Done dot first, before the blanket logo replace swallows its orange
    [[ -f "$res/claude-logo-done.svg" ]] && \
      sub "s/r=\"4.5\" fill=\"#d97757\"/r=\"4.5\" fill=\"$DONE_DOT\"/gi" "$res/claude-logo-done.svg"
    sub "s/#d97757/$ACCENT/gi; s/#c6613f/$ACCENT_DARK/gi" "$css" "$js" "$res"/*.svg
    # Jupyter "connect" banner (also has alpha variants like #f3772633, which this keeps)
    sub "s/#f37726/$ACCENT/gi; s/#f5a66a/$ACCENT_SOFT/gi; s/#3f2a1f/$ACCENT_BG/gi" "$css"

    if [[ "$RAINBOW" == 1 ]]; then
      # Tab/bar icons, clawd and welcome art: add the gradient, point accent fills at it
      perl -pi -e 's{(<svg\b[^>]*>)}{$1$ENV{RC_DEFS}}' "$res"/*.svg
      sub "s/(fill|stroke)=\"$ACCENT\"/\$1=\"url(#rcRainbow)\"/gi" "$res"/*.svg
      # Panel mascot (inline SVG in the JS bundle)
      sub "s/fill:\"$ACCENT\"/fill:\"url(#rcRainbow)\"/gi" "$js"
      # Header wordmark starburst and effort gauge use the *button* variable, not the main accent
      sub 's/(fill|stroke):"var\(--app-claude-(?:clay-button-)?orange\)"/$1:"url(#rcRainbow)"/g' "$js"
      printf '\n%s\n' "$RAINBOW_JS" >> "$js"
      printf '%s' "$RAINBOW_CSS" >> "$css"
    fi

    if [[ "$MODE_COLOURS" == 1 ]]; then
      # Plan / Auto-accept edits / Auto / Bypass permissions style their send button,
      # focus ring and icon from VS Code's own theme tokens, not the extension's
      # branding (see "Permission-mode colours"). This makes them match ACCENT_DARK
      # and ivory instead, same as the default mode already does. Scoped to just
      # these [data-permission-mode=...] rules so real error text elsewhere keeps
      # its actual error colour.
      perl -pi -e '
        s/([^{}]*\[data-permission-mode=[^{}]*)\{([^{}]*)\}/
          my ($sel,$body) = ($1,$2);
          $body =~ s{var\(--vscode-focusBorder,var\(--app-button-background\)\)}{var(--app-claude-clay-button-orange)}g;
          $body =~ s{--app-error-foreground}{--app-claude-clay-button-orange}g;
          $body =~ s{--app-primary-foreground}{--app-claude-clay-button-orange}g;
          $body =~ s{--app-primary-background}{--app-claude-ivory}g;
          $body =~ s{--app-button-foreground}{--app-claude-ivory}g;
          "$sel\{$body\}"
        /gex
      ' "$css"
    fi

    if [[ -f "$CUSTOM_CSS" ]]; then
      printf '\n/* claude-recolor custom.css */\n' >> "$css"
      cat "$CUSTOM_CSS" >> "$css"
    fi

    echo "$WANT" > "$dir/$STAMP"
    echo "claude-recolor: patched $name"
  done
done
