$ErrorActionPreference = "Stop"

function Die($m){ throw $m }

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { Die "Missing file: $path" }

  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan

  $s = Get-Content $path -Raw

  # Remove any stray ":" lines (top-level token that breaks parsing)
  $s = [regex]::Replace($s, '(?m)^\s*:\s*$\r?\n?', '')

  # Replace EVERYTHING from reorder(...) to EOF with a correct, closed method + class brace
  $pattern = '(?ms)^\s*Future<void>\s+reorder\s*\([\s\S]*$'
  if ($s -notmatch $pattern) {
    Die "Could not find reorder(...) near file end to repair. (Expected a Future<void> reorder(...) method.)"
  }

  $replacement = @"
  Future<void> reorder(int oldIndex, int newIndex) async {
    final ordered = _store.reorderLocal(oldIndex, newIndex);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.batchUpdateOrder(_familyId, ordered);
    }
  }
}
"@

  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)
  if ($s2 -eq $s) { Die "Tail repair produced no change (unexpected)." }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Repaired tail + braces in: $path" -ForegroundColor Green

  Write-Host "`nPROOF (last ~40 lines):" -ForegroundColor Yellow
  $lines = Get-Content $path
  $start = [Math]::Max(1, $lines.Count - 40)
  for ($i=$start; $i -le $lines.Count; $i++) {
    "{0,4}: {1}" -f $i, $lines[$i-1]
  }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ task_service.dart should now parse cleanly." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
