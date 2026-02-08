$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  # Ensure UTF-8 WITHOUT BOM
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Replace-Literal([string]$path, [string]$from, [string]$to) {
  $s = Get-Content $path -Raw
  if ($s -notlike "*$from*") { return $false }
  $s2 = $s.Replace($from, $to)
  if ($s2 -eq $s) { return $false }
  WriteUtf8NoBom $path $s2
  return $true
}

try {
  $p1 = "lib/actions/awards/claim_reward_action.dart"
  $p2 = "lib/screens/awards/awards_page.dart"
  $gi = ".gitignore"

  Backup-File $p1
  Backup-File $p2
  if (Test-Path $gi) { Backup-File $gi }

  # ------------------------------------------------------------
  # 1) Fix the remaining lint EXACTLY:
  # Convert:
  #   if (!success) return const ActionResult.failure('...');
  # To:
  #   if (!success) {
  #     return const ActionResult.failure('...');
  #   }
  # ------------------------------------------------------------
  $s = Get-Content $p1 -Raw

  $needle = "if (!success) return const ActionResult.failure('Not enough points or reward disabled.');"
  $replacement = @"
if (!success) {
      return const ActionResult.failure('Not enough points or reward disabled.');
    }
"@.TrimEnd()

  if ($s -like "*$needle*") {
    $s = $s.Replace($needle, $replacement)
    WriteUtf8NoBom $p1 $s
    Write-Host "Patched lint: $p1" -ForegroundColor Green
  } else {
    Write-Host "Did not find exact lint line (still ok). We'll locate it next if analyze still shows it." -ForegroundColor Yellow
  }

  # ------------------------------------------------------------
  # 2) Fix mojibake tokens by simple literal swaps (SAFE)
  # ------------------------------------------------------------
  # claim_reward_action.dart
  $changed = $false
  $changed = (Replace-Literal $p1 "â€œ" '"') -or $changed
  $changed = (Replace-Literal $p1 "â€" '"') -or $changed
  $changed = (Replace-Literal $p1 "â€™" "'") -or $changed

  # awards_page.dart
  $changed2 = $false
  $changed2 = (Replace-Literal $p2 "ðŸŽ" "") -or $changed2
  $changed2 = (Replace-Literal $p2 "ðŸ§¾" "") -or $changed2
  $changed2 = (Replace-Literal $p2 "â€™" "'") -or $changed2
  $changed2 = (Replace-Literal $p2 "â€œ" '"') -or $changed2
  $changed2 = (Replace-Literal $p2 "â€" '"') -or $changed2

  # Now force stable emoji via Dart unicode escapes (target exact strings if present)
  # Rewards Store 🎁 -> Rewards Store \u{1F381}
  Replace-Literal $p2 "Rewards Store 🎁" "Rewards Store \u{1F381}" | Out-Null
  Replace-Literal $p2 "Recent Claims 🧾" "Recent Claims \u{1F9FE}" | Out-Null
  Replace-Literal $p2 "Hey Superstar ⭐" "Hey Superstar \u{2B50}" | Out-Null
  Replace-Literal $p2 "Today’s Tasks ✅" "Today's Tasks \u{2705}" | Out-Null

  # ------------------------------------------------------------
  # 3) Unignore scripts/*.ps1 (append allow rules)
  # ------------------------------------------------------------
  if (Test-Path $gi) {
    $g = Get-Content $gi -Raw
    if ($g -notlike "*!scripts/*") {
      $g += "`n`n# DONEZY: allow tracked PowerShell tooling`n!scripts/`n!scripts/*.ps1`n"
      WriteUtf8NoBom $gi $g
      Write-Host "Patched: .gitignore (allow scripts/*.ps1)" -ForegroundColor Green
    } else {
      Write-Host ".gitignore already allows scripts/*.ps1" -ForegroundColor DarkGray
    }
  }

  Write-Host "`nFormatting touched files..." -ForegroundColor Yellow
  dart format $p1 $p2

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (key files):" -ForegroundColor Yellow
  git --no-pager diff -- $p1 $p2 $gi

  Write-Host "`n✅ Patch complete." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
