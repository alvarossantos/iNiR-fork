#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="niri-theme"

# ── Niri Border / Focus-ring / Tab-indicator color updater ──────────────────
# Reads the generated colors.json and writes ~/.config/niri/theme-active.kdl
# with matching Material You palette colors. Reloads niri at the end.

main() {
  local colors_json="$STATE_DIR/user/generated/colors.json"
  local niri_config_dir="$XDG_CONFIG_HOME/niri"
  local theme_file="$niri_config_dir/theme-active.kdl"

  # Skip if colors.json doesn't exist yet (first boot, etc.)
  [[ -f "$colors_json" ]] || { log_module "colors.json not found, skipping"; exit 0; }
  command -v jq >/dev/null 2>&1 || { log_module "jq not found, skipping"; exit 0; }

  # Extract palette colors
  local active_color inactive_color urgent_color
  active_color=$(jq -r '.primary // empty' "$colors_json" 2>/dev/null) || true
  inactive_color=$(jq -r '.outline_variant // .surface_variant // .outline // empty' "$colors_json" 2>/dev/null) || true
  urgent_color=$(jq -r '.error // .error_container // empty' "$colors_json" 2>/dev/null) || true

  # Fallback defaults if extraction fails
  [[ -n "$active_color" ]]  || active_color="#ADC9E5"
  [[ -n "$inactive_color" ]] || inactive_color="#56423E"
  [[ -n "$urgent_color" ]]  || urgent_color="#EABCB6"

  # Semi-transparent variant of active for insert-hint
  local insert_hint_color="${active_color}80"

  log_module "updating theme-active.kdl: active=$active_color inactive=$inactive_color urgent=$urgent_color"

  mkdir -p "$niri_config_dir"

  cat > "$theme_file" <<KDL
// theme-active.kdl
// Layout completo do iNiR — cores + propriedades estruturais.
// Gerado automaticamente pelo modulo niri-theme do iNiR.
// Nao edite manualmente — sera sobrescrito a cada troca de wallpaper.

layout {
    // Gap between windows and from windows to screen edges (logical px).
    gaps 6

    // Transparent so iNiR's own wallpaper/backdrop shows through.
    background-color "transparent"

    // When focusing a column that's off-screen, how should the view scroll?
    center-focused-column "never"

    // Keep a lone column from hugging the left edge on empty workspaces.
    always-center-single-column

    // Widths cycled by switch-preset-column-width (Mod+R).
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    // Default width for new windows.
    default-column-width {
        proportion 0.5
    }

    // ── Focus ring ──────────────────────────────────────────────────────────
    focus-ring {
        width 3
        active-color "$active_color"
        inactive-color "$inactive_color"
    }

    // ── Border ──────────────────────────────────────────────────────────────
    border {
        width 6
        active-color "$active_color"
        inactive-color "$inactive_color"
        urgent-color   "$urgent_color"
    }

    // ── Shadow ──────────────────────────────────────────────────────────────
    shadow {
        on
        softness 30
        spread 5
        offset x=0 y=5
        color "#0007"
    }

    // ── Struts ──────────────────────────────────────────────────────────────
    struts
    default-column-display "normal"

    // ── Tab indicator ───────────────────────────────────────────────────────
    tab-indicator {
        active-color "$active_color"
        inactive-color "$inactive_color"
        urgent-color   "$urgent_color"
    }

    // ── Insert hint ─────────────────────────────────────────────────────────
    insert-hint {
        color "$insert_hint_color"
    }
}

recent-windows {
    highlight {
        active-color "$active_color"
        urgent-color "$urgent_color"
    }
}
KDL

  log_module "theme-active.kdl written successfully"

  # Reload niri config if the compositor is running
  if command -v niri >/dev/null 2>&1 && niri msg -j focused-output >/dev/null 2>&1; then
    niri msg action load-config-file 2>/dev/null && \
      log_module "niri config reloaded" || \
      log_module "niri config reload failed (non-fatal)"
  fi
}

main "$@"
