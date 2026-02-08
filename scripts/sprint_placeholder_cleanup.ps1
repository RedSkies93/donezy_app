$ErrorActionPreference = "Stop"

function Say($m){ Write-Host $m -ForegroundColor Cyan }
function Die($m){ throw $m }

function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor DarkCyan
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Replace-Exact([string]$path, [string]$from, [string]$to) {
  $s = Get-Content $path -Raw
  if ($s -notlike "*$from*") { return $false }
  $s2 = $s.Replace($from, $to)
  if ($s2 -eq $s) { return $false }
  WriteUtf8NoBom $path $s2
  return $true
}

try {
  $files = @(
    "lib/actions/auth/login_action.dart",
    "lib/actions/auth/logout_action.dart",
    "lib/actions/auth/switch_mode_action.dart",
    "lib/actions/awards/edit_reward_action.dart",
    "lib/actions/awards/toggle_reward_enabled_action.dart",
    "lib/actions/chat/mark_seen_action.dart",
    "lib/actions/chat/open_chat_action.dart",
    "lib/actions/chat/set_chat_scope_action.dart",
    "lib/app/theme/app_text.dart",
    "lib/core/extensions/readme.dart",
    "lib/theme_mode/theme_persistence/theme_prefs.dart",
    "lib/widgets/bouncy_list.dart",
    "lib/widgets/awards/reward_card.dart"
  )

  foreach ($f in $files) { if (Test-Path $f) { Backup-File $f } }

  # ACTION placeholders -> safer docs (no behavior changes)
  if (Test-Path "lib/actions/auth/login_action.dart") {
    Replace-Exact "lib/actions/auth/login_action.dart" "// Phase 1: placeholder (no auth yet)" "// Phase 1: safe no-op (auth wiring comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/auth/logout_action.dart") {
    Replace-Exact "lib/actions/auth/logout_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (auth wiring comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/auth/switch_mode_action.dart") {
    Replace-Exact "lib/actions/auth/switch_mode_action.dart" "// Phase 1: placeholder (parent/child mode switching later)" "// Phase 1: safe no-op (mode switching wiring comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/awards/edit_reward_action.dart") {
    Replace-Exact "lib/actions/awards/edit_reward_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (reward editing UI comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/awards/toggle_reward_enabled_action.dart") {
    Replace-Exact "lib/actions/awards/toggle_reward_enabled_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (reward enable/disable wiring comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/chat/mark_seen_action.dart") {
    Replace-Exact "lib/actions/chat/mark_seen_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (message seen tracking comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/chat/open_chat_action.dart") {
    Replace-Exact "lib/actions/chat/open_chat_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (chat navigation comes later).`n// This action must never throw." | Out-Null
  }
  if (Test-Path "lib/actions/chat/set_chat_scope_action.dart") {
    Replace-Exact "lib/actions/chat/set_chat_scope_action.dart" "// Phase 1: placeholder" "// Phase 1: safe no-op (scope selection persistence comes later).`n// This action must never throw." | Out-Null
  }

  # THEME + EXTENSIONS placeholder comments -> clearer docs
  if (Test-Path "lib/app/theme/app_text.dart") {
    Replace-Exact "lib/app/theme/app_text.dart" "// Phase 1 placeholder; typography system in later phase" "// Phase 1: typography tokens live here. Expand in later phase (no behavior change)." | Out-Null
  }
  if (Test-Path "lib/core/extensions/readme.dart") {
    Replace-Exact "lib/core/extensions/readme.dart" "// Phase 1 placeholder." "// Extensions live here (String/DateTime/BuildContext helpers).`n// Keep this file lightweight and analyzer-clean." | Out-Null
  }
  if (Test-Path "lib/theme_mode/theme_persistence/theme_prefs.dart") {
    Replace-Exact "lib/theme_mode/theme_persistence/theme_prefs.dart" "// Phase 1: placeholder (in-memory only)" "// Phase 1: in-memory only.`n// Later phase: persist using shared_preferences (or secure storage if needed)." | Out-Null
  }

  # WIDGET placeholders (safe swap)
  if (Test-Path "lib/widgets/bouncy_list.dart") {
    Replace-Exact "lib/widgets/bouncy_list.dart" "// Phase 1: placeholder; Phase 2 adds bounce physics feel" "// Phase 1: simple wrapper. Phase 2 adds bounce physics feel (no behavior risk now)." | Out-Null
  }
  if (Test-Path "lib/widgets/awards/reward_card.dart") {
    Replace-Exact "lib/widgets/awards/reward_card.dart" "const ListTile(title: Text('RewardCard (placeholder)'));" "const SizedBox.shrink();" | Out-Null
  }

  Say "`nFormatting..."
  dart format .
  if ($LASTEXITCODE -ne 0) { Die "dart format failed" }

  Say "`nAnalyze..."
  flutter analyze
  if ($LASTEXITCODE -ne 0) { Die "flutter analyze failed" }

  Say "`nTest..."
  flutter test
  if ($LASTEXITCODE -ne 0) { Die "flutter test failed" }

  Say "`nDiff summary (stats):"
  git --no-pager diff --stat

  Say "`nCommit + push"
  git add -A
  git commit -m "Replace Phase-1 placeholders with safer docs + cleanup placeholder widget"
  git push origin main

  Write-Host "`n✅ DONE — Placeholder cleanup shipped" -ForegroundColor Green
} catch {
  Write-Host "`n❌ FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
  Write-Host "`nTIP: run: git --no-pager diff" -ForegroundColor Yellow
  exit 1
} finally {
  Read-Host "Press Enter to close"
}
