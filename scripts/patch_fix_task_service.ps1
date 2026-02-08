$ErrorActionPreference = "Stop"

function Die($msg) { throw $msg }

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { Die "Missing file: $path" }

  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan

  $s = Get-Content $path -Raw

  if ($s -notmatch 'updateTaskFields') {
    Die "No 'updateTaskFields' found in $path. Nothing to remove. (Share the diff snippet around line ~240.)"
  }

  # Remove the entire stray method block (wherever it exists)
  # Matches: Future<void> updateTaskFields(...) async { ... }
  $pattern = '(?ms)^\s*Future<\s*void\s*>\s+updateTaskFields\s*\([\s\S]*?\)\s*async\s*\{[\s\S]*?\}\s*'
  $s2 = [regex]::Replace($s, $pattern, "", 1)

  if ($s2 -eq $s) {
    Die "Found 'updateTaskFields' but regex removal did not change file. Printing surrounding context for manual targeting."
  }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Removed stray updateTaskFields block from: $path" -ForegroundColor Green

  Write-Host "`nPROOF (should be empty):" -ForegroundColor Yellow
  Select-String -Path $path -Pattern "updateTaskFields" -SimpleMatch -ErrorAction SilentlyContinue

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
