$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/task_store.dart"
  Backup-File $path

  $s = Get-Content $path -Raw

  # Replace the whole updateLocal method (including indentation) exactly once.
  $pattern = '(?ms)^\s*void\s+updateLocal\s*\(\s*TaskModel\s+updated\s*\)\s*\{[\s\S]*?\}\s*\r?\n\s*void\s+deleteLocal\s*\('
  if ($s -notmatch $pattern) { Die "Could not find updateLocal(...) followed by deleteLocal(...) to reformat in $path" }

  $replacement = @"
  void updateLocal(TaskModel updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;

    final next = _tasks.toList();
    next[index] = updated;
    next.sort((a, b) => a.order.compareTo(b.order));
    _tasks = List.unmodifiable(next);

    notifyListeners();
  }

  void deleteLocal(
"@

  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)

  # Trim trailing whitespace/blank lines at EOF
  $s2 = [regex]::Replace($s2, '(\s*\r?\n)+\z', "`r`n")

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Polished: $path (indentation + EOF cleanup)" -ForegroundColor Green

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit --no-pager diff (task_store.dart only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/services/task_store.dart

  Write-Host "`n✅ task_store.dart formatted cleanly." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
