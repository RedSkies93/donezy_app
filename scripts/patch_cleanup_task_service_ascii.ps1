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

  Write-Host "`nPROOF BEFORE: lines that are ONLY ':'" -ForegroundColor Yellow
  Select-String -Path $path -Pattern '^\s*:\s*$' -AllMatches -ErrorAction SilentlyContinue |
    ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }

  Write-Host "`nPROOF BEFORE: any garbled 'aEUR' sequences" -ForegroundColor Yellow
  Select-String -Path $path -Pattern 'aEUR' -AllMatches -ErrorAction SilentlyContinue |
    ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }

  # 1) Remove any line that is ONLY ":" (optionally surrounded by whitespace)
  $s = [regex]::Replace($s, '(?m)^\s*:\s*$\r?\n?', '')

  # 2) Normalize common garbled sequences -> plain ASCII
  # Replace the most common artifacts you showed: "â€”" and "â†”"
  $s = $s.Replace("â€”", "--")
  $s = $s.Replace("â†”", "<->")

  Set-Content -Encoding UTF8 $path $s
  Write-Host "`nPatched: $path (removed ':' + normalized comment encoding to ASCII)" -ForegroundColor Green

  Write-Host "`nPROOF AFTER: lines that are ONLY ':' (should be none)" -ForegroundColor Yellow
  Select-String -Path $path -Pattern '^\s*:\s*$' -AllMatches -ErrorAction SilentlyContinue |
    ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ Cleanup complete." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
