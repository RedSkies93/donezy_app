$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function Remove-WrongOnEdit([string]$path) {
  Backup-File $path
  $s = Get-Content $path -Raw
  $before = $s

  # Remove ONLY the incorrect/auto-inserted onEdit one-liner variants
  # (handles both: run(context, task: t) and run(context: context, task: t) just in case)
  $s = [regex]::Replace($s, "(?m)^\s*onEdit:\s*\(\)\s*=>\s*EditTaskAction\(\)\.run\(\s*context\s*,\s*task:\s*t\s*\)\s*,\s*\r?\n", "")
  $s = [regex]::Replace($s, "(?m)^\s*onEdit:\s*\(\)\s*=>\s*EditTaskAction\(\)\.run\(\s*context:\s*context\s*,\s*task:\s*t\s*\)\s*,\s*\r?\n", "")

  if ($s -eq $before) {
    Write-Host "No auto-inserted onEdit one-liner found in: $path (ok)" -ForegroundColor DarkGray
    return
  }

  Set-Content -Encoding UTF8 $path $s
  Write-Host "Patched: $path (removed auto-inserted onEdit one-liner)" -ForegroundColor Green
}

try {
  Remove-WrongOnEdit "lib/screens/parent/parent_dashboard_page.dart"
  Remove-WrongOnEdit "lib/screens/child/child_dashboard_page.dart"

  Write-Host "`nPROOF: show onEdit lines in dashboards:" -ForegroundColor Yellow
  Select-String -Path lib/screens/parent/parent_dashboard_page.dart,lib/screens/child/child_dashboard_page.dart -Pattern '\bonEdit\s*:' |
    ForEach-Object { "{0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (dashboards only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/screens/parent/parent_dashboard_page.dart lib/screens/child/child_dashboard_page.dart

  Write-Host "`n✅ Dashboards cleaned: parent keeps bulk-mode edit handler, child remains hidden." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
