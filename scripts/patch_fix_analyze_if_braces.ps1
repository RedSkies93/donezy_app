$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function Enclose-IfBody([string]$path, [string]$pattern, [string]$replacementLabel) {
  Backup-File $path
  $s = Get-Content $path -Raw
  $before = $s

  # Single targeted replacement (first match only) to avoid touching unrelated ifs.
  $s2 = [regex]::Replace($s, $pattern, $replacementLabel, 1)

  if ($s2 -eq $before) {
    Write-Host "No match (already fixed?) -> $path" -ForegroundColor DarkGray
    return
  }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path" -ForegroundColor Green
}

try {
  # ------------------------------------------------------------
  # 1) lib/actions/awards/claim_reward_action.dart
  # Typical lint trigger: if (cond) return ...;  OR if (cond) doSomething();
  # We'll wrap a single-line if statement into a block.
  # ------------------------------------------------------------
  $p1 = "lib/actions/awards/claim_reward_action.dart"

  # Pattern: if (<anything>) <single statement>;
  # Replacement: if (...) { <single statement>; }
  Enclose-IfBody $p1 '(?m)^\s*if\s*\(([^)]+)\)\s*([^{};\r\n]+;)\s*$' 'if ($1) { $2 }'

  # ------------------------------------------------------------
  # 2) lib/screens/awards/awards_page.dart
  # Same style fix.
  # ------------------------------------------------------------
  $p2 = "lib/screens/awards/awards_page.dart"
  Enclose-IfBody $p2 '(?m)^\s*if\s*\(([^)]+)\)\s*([^{};\r\n]+;)\s*$' 'if ($1) { $2 }'

  Write-Host "`nRunning dart format on touched files..." -ForegroundColor Yellow
  dart format $p1 $p2

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`n✅ analyze should be 0 now." -ForegroundColor Green

  Write-Host "`nGit diff (only the 2 files):" -ForegroundColor Yellow
  git --no-pager diff -- $p1 $p2
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
