$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Say($m){ Write-Host $m -ForegroundColor Cyan }

function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

try {
  $p = "lib/screens/awards/awards_page.dart"
  Backup-File $p

  $s = Get-Content $p -Raw

  # EXACT bad tokens seen in your error output
  $bad1  = "'Rewards Store \u{1F381}' \u{1F381}',"
  $good1 = "'Rewards Store \u{1F381}',"

  $bad2  = "'Recent Claims \u{1F9FE}' \u{1F9FE}',"
  $good2 = "'Recent Claims \u{1F9FE}',"

  $changed = $false

  if ($s -like "*$bad1*") { $s = $s.Replace($bad1, $good1); $changed = $true }
  if ($s -like "*$bad2*") { $s = $s.Replace($bad2, $good2); $changed = $true }

  if (-not $changed) {
    Die "Did not find the exact broken tokens. Paste lines ~70-95 from $p and we'll patch by exact lines."
  }

  WriteUtf8NoBom $p $s
  Write-Host "Patched: $p" -ForegroundColor Green

  Say "`nFormat (AwardsPage only)"
  dart format $p
  if ($LASTEXITCODE -ne 0) { Die "dart format failed" }

  Say "`nAnalyze"
  flutter analyze
  if ($LASTEXITCODE -ne 0) { Die "flutter analyze failed" }

  Say "`nTest"
  flutter test
  if ($LASTEXITCODE -ne 0) { Die "flutter test failed" }

  Say "`nDiff (AwardsPage only)"
  git --no-pager diff -- $p

  Say "`nCommit + push hotfix"
  git add $p
  git commit -m "Hotfix: repair AwardsPage unicode escape strings"
  git push origin main

  Write-Host "`n✅ HOTFIX SHIPPED" -ForegroundColor Green
}
catch {
  Write-Host "`n❌ HOTFIX FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
