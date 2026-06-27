#!/bin/bash
# =============================================================================
# theme.sh — 系统主题检测（Linux / macOS）
# 检测当前系统为深色或浅色主题，输出 Mermaid 主题变量 JSON。
#
# 用法:
#   bash theme.sh
#
# 输出 JSON:
#   {"mermaidTheme":"dark|neutral","mermaidThemeInit":"%%{init: {\"theme\": \"dark|neutral\"}}%%"}
# =============================================================================

set -o pipefail

detect_theme() {
  case "$(uname -s)" in
    Darwin)
      # macOS: AppleInterfaceStyle → "Dark" 或 nil
      local result
      result=$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)
      if [ -n "$result" ]; then
        echo "dark"
      else
        echo "neutral"
      fi
      ;;
    *)
      # Linux (GNOME): color-scheme → "prefer-dark" 或 "default"
      local result
      result=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)
      if [[ "$result" == *dark* ]]; then
        echo "dark"
      else
        # 兜底: 检查 GTK 主题名称
        result=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)
        if [[ "$result" == *dark* || "$result" == *Dark* ]]; then
          echo "dark"
        else
          echo "neutral"
        fi
      fi
      ;;
  esac
}

# --- Main ---
THEME=$(detect_theme)
MERMAID_INIT="%%{init: {\"theme\": \"${THEME}\"}}%%"

if command -v jq &>/dev/null; then
  jq -n \
    --arg theme "$THEME" \
    --arg init "$MERMAID_INIT" \
    '{"mermaidTheme":$theme,"mermaidThemeInit":$init}'
else
  ESCAPED=$(printf '%s' "$MERMAID_INIT" | sed 's/"/\\"/g')
  printf '{"mermaidTheme":"%s","mermaidThemeInit":"%s"}\n' "$THEME" "$ESCAPED"
fi
