$ErrorActionPreference = "Stop"

function Say($m){ Write-Host $m -ForegroundColor Cyan }
function Die($m){ throw $m }

function WriteUtf8NoBom([string]$path, [string]$content) {
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
  Say "Repo: $(Get-Location)"

  # ------------------------------------------------------------
  # 1) Hard-set AwardsPage headings to stable unicode escapes
  # (NO emoji literals in this script)
  # ------------------------------------------------------------
  $aw = "lib/screens/awards/awards_page.dart"
  if (!(Test-Path $aw)) { Die "Missing file: $aw" }

  # These are safe ASCII sequences in the source after prior edits:
  # If the file already has these exact strings, no change will occur.
  Replace-Literal $aw "Rewards Store \u{1F381}" "Rewards Store \u{1F381}" | Out-Null
  Replace-Literal $aw "Recent Claims \u{1F9FE}" "Recent Claims \u{1F9FE}" | Out-Null

  # If you still have corrupted variants, force-replace by broad stable anchors:
  # We only touch lines containing these anchors by doing two-step replace:
  Replace-Literal $aw "'Rewards Store" "'Rewards Store \u{1F381}'" | Out-Null
  Replace-Literal $aw "'Recent Claims" "'Recent Claims \u{1F9FE}'" | Out-Null

  # ------------------------------------------------------------
  # 2) Normalize line endings via git renormalize (respects .gitattributes)
  # ------------------------------------------------------------
  Say "`n[1/4] Renormalize line endings"
  git add --renormalize . | Out-Null

  # ------------------------------------------------------------
  # 3) Format + analyze + test
  # ------------------------------------------------------------
  Say "`n[2/4] dart format ."
  dart format .

  Say "`n[3/4] flutter analyze"
  flutter analyze

  Say "`n[4/4] flutter test"
  flutter test

  Write-Host "`n✅ Preflight OK" -ForegroundColor Green

  # ------------------------------------------------------------
  # 4) Stage everything (including scripts) and commit/push
  # ------------------------------------------------------------
  Say "`nStage all changes"
  git add -A

  Say "`nStatus:"
  git status

  Say "`nCommit + push"
  git commit -m "Normalize line endings + keep analyze 0 + track scripts tooling"
  git push origin main

  Say "`nPROOF: clean status"
  git status
}
catch {
  Write-Host "`n❌ FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
