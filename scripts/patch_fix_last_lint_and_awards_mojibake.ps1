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

function Dump-Lines([string]$path, [int]$from, [int]$to) {
  Write-Host "`n=== $path lines $from..$to ===" -ForegroundColor Yellow
  $lines = Get-Content $path
  for ($i=$from; $i -le $to; $i++) {
    if ($i -ge 1 -and $i -le $lines.Count) {
      "{0,4}: {1}" -f $i, $lines[$i-1]
    }
  }
}

function Replace-Line-Contains([string]$path, [string]$contains, [string]$newLine) {
  $lines = Get-Content $path
  $idx = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains($contains)) { $idx = $i; break }
  }
  if ($idx -lt 0) { return $false }
  $lines[$idx] = $newLine
  $out = ($lines -join "`n") + "`n"
  WriteUtf8NoBom $path $out
  return $true
}

function Fix-IfReturn-WithBraces([string]$path, [string]$needlePrefix) {
  # Finds the FIRST line that starts with the prefix and ends with ';'
  # and wraps it into a 3-line brace block.
  $lines = Get-Content $path
  for ($i=0; $i -lt $lines.Count; $i++) {
    $trim = $lines[$i].Trim()
    if ($trim.StartsWith($needlePrefix) -and $trim.EndsWith(";") -and $trim -notlike "*{*") {
      $indent = ($lines[$i] -replace '^(\s*).*$','$1')
      $stmt = $trim.Substring($needlePrefix.Length).Trim()
      # $stmt is like: "return const ActionResult.failure('...');"
      $lines[$i] = "${indent}${needlePrefix} {"
      $lines[$i+1] = "${indent}  $stmt"
      $lines = @($lines[0..$i]) + @($lines[$i+1]) + @("${indent}}") + @($lines[($i+2)..($lines.Count-1)])
      $out = ($lines -join "`n") + "`n"
      WriteUtf8NoBom $path $out
      return $true
    }
  }
  return $false
}

try {
  $p1 = "lib/actions/awards/claim_reward_action.dart"
  $p2 = "lib/screens/awards/awards_page.dart"

  Backup-File $p1
  Backup-File $p2

  # 1) Show the exact lint area so it's transparent
  Dump-Lines $p1 45 65

  # 2) Fix the EXACT lint: the remaining one is almost certainly:
  #    if (!success) return const ActionResult.failure(...);
  # We'll transform ONLY that style.
  $did = Fix-IfReturn-WithBraces $p1 "if (!success)"
  if ($did) {
    Write-Host "Patched lint if(!success) in: $p1" -ForegroundColor Green
  } else {
    Write-Host "Did not find a one-line if(!success) return; to wrap. We'll search the file next." -ForegroundColor Yellow
  }

  # 3) Hard-set AwardsPage title lines using unicode escapes (stable + no mojibake)
  # NOTE: These are the *exact* lines you want inside Text('...'):
  #       'Rewards Store \u{1F381}',
  #       'Recent Claims \u{1F9FE}',
  $ok1 = Replace-Line-Contains $p2 "Rewards Store" "                    'Rewards Store \u{1F381}',"
  $ok2 = Replace-Line-Contains $p2 "Recent Claims" "                    'Recent Claims \u{1F9FE}',"

  if ($ok1) { Write-Host "Patched Rewards Store line: $p2" -ForegroundColor Green } else { Write-Host "Could not find Rewards Store line to patch." -ForegroundColor Yellow }
  if ($ok2) { Write-Host "Patched Recent Claims line: $p2" -ForegroundColor Green } else { Write-Host "Could not find Recent Claims line to patch." -ForegroundColor Yellow }

  Write-Host "`nFormatting touched files..." -ForegroundColor Yellow
  dart format $p1 $p2

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (only these files):" -ForegroundColor Yellow
  git --no-pager diff -- $p1 $p2

  Write-Host "`n✅ Done." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
