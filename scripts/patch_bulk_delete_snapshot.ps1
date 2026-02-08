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

  # Replace the whole deleteMany method body with a snapshot-safe version
  $pattern = "(?s)Future<void>\s+deleteMany\s*\(\s*Set<String>\s+ids\s*\)\s+async\s*\{[\s\S]*?\n\s*\}\s*"
  if ($s -notmatch $pattern) { throw "Anchor not found: Future<void> deleteMany(Set<String> ids) async { ... }" }

  $replacement = @"
Future<void> deleteMany(Set<String> ids) async {
    if (ids.isEmpty) return;

    // SNAPSHOT: ids may be a live Set owned by UI selection state.
    final idList = ids.toList(growable: false);

    for (final id in idList) {
      _store.deleteLocal(id);
    }

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.deleteMany(_familyId, idList.toSet());
    }
  }

"@

  $s = [regex]::Replace($s, $pattern, $replacement, 1)

  if ($s -eq $orig) { throw "Replace failed unexpectedly; no changes applied." }

  Set-Content -Encoding UTF8 -Path $path -Value $s
  Write-Host "PATCHED: deleteMany now snapshots ids and deletes ALL reliably" -ForegroundColor Green

  Write-Host "`n=== PROOF (deleteMany) ===" -ForegroundColor Cyan
  Select-String -Path $path -Pattern "Future<void>\s+deleteMany|SNAPSHOT|idList|deleteMany\(_familyId" -Context 0,6

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
