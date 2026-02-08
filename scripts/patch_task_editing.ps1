# ============================================================
# DONEZY — Task Editing UX Patch (SAFE + LOUD)
# Fix: TaskStore.updateLocal was mutating List.unmodifiable (_tasks)
# ============================================================

$ErrorActionPreference = "Stop"

function Die($msg) { throw $msg }

function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  # ------------------------------------------------------------
  # FILE: lib/services/task_store.dart
  # ------------------------------------------------------------
  $path = "lib/services/task_store.dart"
  Backup-File $path

  $s = Get-Content $path -Raw

  # Replace ONLY updateLocal(...) method with a safe implementation
  $pattern = 'void\s+updateLocal\s*\(\s*TaskModel\s+\w+\s*\)\s*\{[\s\S]*?\}\s*'
  if ($s -notmatch $pattern) {
    Die "Could not find updateLocal(TaskModel ...) method to patch in $path"
  }

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
"@

  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)
  if ($s2 -eq $s) { Die "Patch produced no changes (unexpected) in $path" }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path (updateLocal is now safe)" -ForegroundColor Green

  Write-Host "`nPROOF (method header):" -ForegroundColor Yellow
  Select-String -Path $path -Pattern "void updateLocal" | ForEach-Object { $_.Line }

  # ------------------------------------------------------------
  # VERIFICATION
  # ------------------------------------------------------------
  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ Patch applied successfully." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
