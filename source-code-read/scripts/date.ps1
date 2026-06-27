# =============================================================================
# date.ps1 — 日期命令生成（Windows）
# 输出适用于 Windows（PowerShell）的日期时间命令字符串 JSON。
#
# 用法:
#   powershell -File date.ps1
#
# 输出 JSON:
#   {"dateCmdFull":"powershell -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm'\"","dateCmdCompact":"powershell -Command \"Get-Date -Format 'yyyyMMddHHmmss'\""}
# =============================================================================

$dateCmdFull    = "powershell -Command ""Get-Date -Format 'yyyy-MM-dd HH:mm'"""
$dateCmdCompact = "powershell -Command ""Get-Date -Format 'yyyyMMddHHmmss'"""

$result = @{
    dateCmdFull    = $dateCmdFull
    dateCmdCompact = $dateCmdCompact
}
ConvertTo-Json -InputObject $result -Compress
