# ============================================================
# DONEZY — Preflight (format + analyze + test)
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
# ============================================================

$ErrorActionPreference = "Stop"
function Say($m){ Write-Host $m -ForegroundColor Cyan }
function Die($m){ throw $m }

try {
  Say "Repo: $(Get-Location)"
  Say "Flutter: $(flutter --version | Select-Object -First 1)"

  Say "`n[1/4] flutter pub get"
  flutter pub get

  Say "`n[2/4] dart format ."
  dart format .

  Say "`n[3/4] flutter analyze"
  flutter analyze

  Say "`n[4/4] flutter test"
  flutter test

  Write-Host "`n✅ Preflight OK (format + analyze + test)" -ForegroundColor Green
}
catch {
  Write-Host "`n❌ Preflight FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
