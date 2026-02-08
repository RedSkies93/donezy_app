$ErrorActionPreference = "Stop"

function Backup-File($path) {
  $bak = "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  Backup-File $path | Out-Null
  $s    = Get-Content $path -Raw
  $orig = $s

  # REMOVE the orphaned block that starts at column 0:
  # if (_firebaseOn) { await _ensureSignedIn(); await _firestore!.deleteMany(_familyId, ids); }
  $pattern = "(?ms)^\s*if\s*\(\s*_firebaseOn\s*\)\s*\{\s*await\s+_ensureSignedIn\(\);\s*await\s+_firestore!\.deleteMany\(_familyId,\s*ids\);\s*\}\s*"

  $s = [regex]::Replace($s, $pattern, "", 1)

  if ($s -eq $orig) {
    Write-Host "No orphan block found (already fixed?)" -ForegroundColor Yellow
  } else {
    Set-Content -Encoding UTF8 -Path $path -Value $s
    Write-Host "FIXED: orphaned deleteMany block removed" -ForegroundColor Green
  }

  Write-Host "`n=== PROOF (structure restored) ===" -ForegroundColor Cyan
  Select-String -Path $path -Pattern "Future<void> renameTask|setDueDate|reorder" -Context 0,2

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force
}
finally {
  Read-Host "`nPress Enter to close"
}
