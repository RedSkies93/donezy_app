$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/task_service.dart"
  Backup-File $path

  $s = Get-Content $path -Raw

  # PROOF BEFORE
  Write-Host "`nPROOF BEFORE: stray ':' lines" -ForegroundColor Yellow
  Select-String -Path $path -Pattern '^\s*:\s*$' -AllMatches | ForEach-Object { "$($_.LineNumber): $($_.Line)" }

  Write-Host "`nPROOF BEFORE: garbled sequences" -ForegroundColor Yellow
  Select-String -Path $path -Pattern 'â€”|â†”' -AllMatches -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LineNumber): $($_.Line)" }

  # 1) Remove any line that is ONLY ":" (optionally surrounded by whitespace)
  $s = [regex]::Replace($s, '(?m)^\s*:\s*$\r?\n?', '')

  # 2) Fix garbled comment characters (encoding artifacts)
  $s = $s.Replace('â€”', '—')   # em dash
  $s = $s.Replace('â†”', '↔')   # left-right arrow

  Set-Content -Encoding UTF8 $path $s
  Write-Host "`nPatched: $path (removed ':' + fixed comment encoding)" -ForegroundColor Green

  # PROOF AFTER
  Write-Host "`nPROOF AFTER: stray ':' lines (should be none)" -ForegroundColor Yellow
  Select-String -Path $path -Pattern '^\s*:\s*$' -AllMatches -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LineNumber): $($_.Line)" }

  Write-Host "`nPROOF AFTER: garbled sequences (should be none)" -ForegroundColor Yellow
  Select-String -Path $path -Pattern 'â€”|â†”' -AllMatches -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LineNumber): $($_.Line)" }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ Cleanup complete. No Task Editing logic changed." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
