$ErrorActionPreference = "Stop"

function Say($m){ Write-Host $m -ForegroundColor Cyan }
function Die($m){ throw $m }

try {
  Say "Repo: $(Get-Location)"
  Say "Branch: $(git rev-parse --abbrev-ref HEAD)"
  Say "Flutter: $(flutter --version | Select-Object -First 1)"

  # ------------------------------------------------------------
  # 1) Git safety: stop CRLF churn in THIS repo
  # ------------------------------------------------------------
  Say "`n[1/6] Git line-ending safety (repo local)"
  git config core.autocrlf false
  git config core.eol lf

  # ------------------------------------------------------------
  # 2) Renormalize using .gitattributes
  # ------------------------------------------------------------
  Say "`n[2/6] Renormalize line endings (respects .gitattributes)"
  git add --renormalize .
  # NOTE: renormalize may stage changes. That's intended.

  # ------------------------------------------------------------
  # 3) Pub get
  # ------------------------------------------------------------
  Say "`n[3/6] flutter pub get"
  flutter pub get
  if ($LASTEXITCODE -ne 0) { Die "pub get failed" }

  # ------------------------------------------------------------
  # 4) Format
  # ------------------------------------------------------------
  Say "`n[4/6] dart format ."
  dart format .
  if ($LASTEXITCODE -ne 0) { Die "format failed" }

  # ------------------------------------------------------------
  # 5) Analyze
  # ------------------------------------------------------------
  Say "`n[5/6] flutter analyze"
  flutter analyze
  if ($LASTEXITCODE -ne 0) { Die "analyze failed" }

  # ------------------------------------------------------------
  # 6) Tests
  # ------------------------------------------------------------
  Say "`n[6/6] flutter test"
  flutter test
  if ($LASTEXITCODE -ne 0) { Die "tests failed" }

  Write-Host "`n✅ ALL GREEN" -ForegroundColor Green

  Say "`nStatus:"
  git status

} catch {
  Write-Host "`n❌ FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
  exit 1
} finally {
  Read-Host "Press Enter to close"
}
