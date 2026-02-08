$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
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
  $p = "lib/actions/awards/claim_reward_action.dart"
  Backup-File $p

  $s = Get-Content $p -Raw

  $bad = 'Text(''"$\{reward.title\}"'','
  $good = 'Text(''"${reward.title}"'','

  if ($s -notlike "*$bad*") {
    Die "Did not find the exact bad token to replace:`n$bad"
  }

  $s2 = $s.Replace($bad, $good)
  WriteUtf8NoBom $p $s2
  Write-Host "Patched: removed bad escapes in title Text(...): $p" -ForegroundColor Green

  Write-Host "`nFormatting..." -ForegroundColor Yellow
  dart format $p

  Write-Host "`nAnalyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nDiff (claim only):" -ForegroundColor Yellow
  git --no-pager diff -- $p

  Write-Host "`n✅ DONE" -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
