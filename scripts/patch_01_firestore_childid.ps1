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

  # If already present, stop
  if ($s -match "(?m)^\s*'childId'\s*:\s*t\.childId,\s*$") {
    Write-Host "OK: _toMap already writes childId." -ForegroundColor Yellow
  } else {
    # Insert childId immediately after: 'title': t.title,
    $pattern = "(?m)^(?<indent>\s*)'title'\s*:\s*t\.title,\s*$"
    if ($s -notmatch $pattern) { throw "Anchor not found in _toMap:  'title': t.title," }

    $nl = [Environment]::NewLine
    $s2 = [regex]::Replace($s, $pattern, { param($m)
      $indent = $m.Groups["indent"].Value
      return ($m.Value + $nl + $indent + "'childId': t.childId,")
    }, 1)

    if ($s2 -eq $s) { throw "Replace failed unexpectedly; no changes applied." }

    Set-Content -Encoding UTF8 -Path $path -Value $s2
    Write-Host "PATCHED: inserted 'childId': t.childId, into _toMap" -ForegroundColor Green
  }

  Write-Host "`n=== PROOF (_toMap has childId) ===" -ForegroundColor Cyan
  Select-String -Path $path -Pattern "Map<String, dynamic> _toMap|'\s*title'\s*:\s*t\.title|'\s*childId'\s*:\s*t\.childId" -Context 0,8

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force
  Write-Host "`nSTOPPED. Terminal will remain open." -ForegroundColor Red
}
finally {
  Read-Host "`nPress Enter to close"
}
