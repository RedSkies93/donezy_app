$ErrorActionPreference = "Stop"

function Backup-File($path) {
  $bak = "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/firestore_service.dart"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  Backup-File $path | Out-Null
  $s = Get-Content $path -Raw

  if ($s -match "(?m)^\s*'childId'\s*:\s*t\.childId,\s*$") {
    Write-Host "Already patched: _toMap already writes childId." -ForegroundColor Yellow
  } else {
    $anchor = "(?m)^\s*'title'\s*:\s*t\.title,\s*$"
    if ($s -notmatch $anchor) { throw "Anchor not found in _toMap map: `'title': t.title,`" }

    $s = [regex]::Replace(
      $s,
      $anchor,
      "      'title': t.title,`n      'childId': t.childId,",
      1
    )

    Set-Content -Encoding UTF8 -Path $path -Value $s
    Write-Host "Patched: $path  (inserted 'childId': t.childId into _toMap)" -ForegroundColor Green
  }

  Write-Host "`n=== PROOF (_toMap childId write) ===" -ForegroundColor Cyan
  Select-String -Path $path -Pattern "Map<String, dynamic> _toMap|'\s*title'\s*:\s*t\.title|'\s*childId'\s*:\s*t\.childId" -Context 0,6

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze

  Write-Host "`nNEXT (do this now):" -ForegroundColor Cyan
  Write-Host "1) In your running flutter run terminal, press R (hot restart)" -ForegroundColor Cyan
  Write-Host "2) Select Child 1 -> Add NEW task -> should appear under Child 1" -ForegroundColor Cyan
  Write-Host "3) Select Child 2 -> Add NEW task -> should appear under Child 2" -ForegroundColor Cyan
  Write-Host "4) All -> should show both" -ForegroundColor Cyan
  Write-Host "`nNOTE: Old tasks created before this fix may still have childId=null in Firestore." -ForegroundColor Yellow
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force

  Write-Host "`n=== flutter analyze (at error) ===" -ForegroundColor Yellow
  try { flutter analyze } catch {}

  Write-Host "`nSTOPPED. Terminal will remain open." -ForegroundColor Red
}
finally {
  Read-Host "`nPress Enter to close"
}
