$ErrorActionPreference = "Stop"

function Backup-File($path) {
  $bak = "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  Backup-File $path | Out-Null
  $s = Get-Content $path -Raw
  $orig = $s

  # Replace: for (final id in taskIds) { ... }
  # With:    final ids = taskIds.toList(growable: false); for (final id in ids) { ... }
  $pattern = "(?ms)^\s*for\s*\(\s*final\s+(\w+)\s+in\s+taskIds\s*\)\s*\{"
  if ($s -notmatch $pattern) { throw "Anchor not found: for (final <id> in taskIds) {" }

  $s = [regex]::Replace($s, $pattern, {
    param($m)
    $idVar = $m.Groups[1].Value
    return "    final ids = taskIds.toList(growable: false);`n    for (final $idVar in ids) {"
  }, 1)

  if ($s -ne $orig) {
    Set-Content -Encoding UTF8 -Path $path -Value $s
    Write-Host "PATCHED: deleteMany now iterates snapshot list (no concurrent modification)" -ForegroundColor Green
  } else {
    Write-Host "No changes made (already patched?)" -ForegroundColor Yellow
  }

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force
  Write-Host "`nSTOPPED. Terminal will remain open." -ForegroundColor Red
}
finally {
  Read-Host "`nPress Enter to close"
}
