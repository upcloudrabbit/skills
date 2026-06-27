#!/bin/bash
# =============================================================================
# date.sh — 日期命令生成（Linux / macOS）
# 输出适用于 Linux/macOS 的日期时间命令字符串 JSON。
#
# 用法:
#   bash date.sh
#
# 输出 JSON:
#   {"dateCmdFull":"date '+%Y-%m-%d %H:%M'","dateCmdCompact":"date '+%Y%m%d%H%M%S'"}
# =============================================================================

DATE_FULL="date '+%Y-%m-%d %H:%M'"
DATE_COMPACT="date '+%Y%m%d%H%M%S'"

if command -v jq &>/dev/null; then
  jq -n \
    --arg full "$DATE_FULL" \
    --arg compact "$DATE_COMPACT" \
    '{"dateCmdFull":$full,"dateCmdCompact":$compact}'
else
  printf '{"dateCmdFull":"%s","dateCmdCompact":"%s"}\n' "$DATE_FULL" "$DATE_COMPACT"
fi
