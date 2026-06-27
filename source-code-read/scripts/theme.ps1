# =============================================================================
# theme.ps1 — 系统主题检测（Windows）
# 通过注册表检测 Windows 深色/浅色主题，输出 Mermaid 主题变量 JSON。
#
# 用法:
#   powershell -File theme.ps1
#
# 输出 JSON:
#   {"mermaidTheme":"dark|neutral","mermaidThemeInit":"%%{init: {\"theme\": \"dark|neutral\"}}%%"}
# =============================================================================

$theme = "neutral"
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $value = (Get-ItemProperty -Path $regPath -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
    if ($value -eq 0) {
        $theme = "dark"
    }
} catch {
    # 注册表路径不可用时默认 neutral
}

$mermaidThemeInit = '%%{init: {"theme": "' + $theme + '"}}%%'

$result = @{
    mermaidTheme     = $theme
    mermaidThemeInit = $mermaidThemeInit
}
ConvertTo-Json -InputObject $result -Compress
