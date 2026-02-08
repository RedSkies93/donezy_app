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

  $lines = Get-Content $p
  $idx = -1

  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains('${reward.title}')) { $idx = $i; break }
  }
  if ($idx -lt 0) { Die "Could not find any line containing `${reward.title}` in $p" }

  $indent = ($lines[$idx] -replace '^(\s*).*$','$1')

  # Replace JUST that line (keep trailing comma, style stays on next line)
  $lines[$idx] = $indent + "Text('`"`$\{reward.title\}`"`',"

  $out = ($lines -join "`n") + "`n"
  WriteUtf8NoBom $p $out
  Write-Host "Patched title mojibake line: $p" -ForegroundColor Green

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
