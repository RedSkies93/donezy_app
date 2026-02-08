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

  # Replace ONLY the updateLocal(...) method body with a correct block,
  # and ensure deleteLocal starts on its own line.
  $pattern = '(?ms)void\s+updateLocal\s*\(\s*TaskModel\s+updated\s*\)\s*\{[\s\S]*?\}\s*void\s+deleteLocal\s*\('
  if ($s -notmatch $pattern) { Die "Could not find the merged updateLocal/deleteLocal boundary to fix in $path" }

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
  if ($s2 -eq $s) { Die "Patch produced no changes (unexpected) in $path" }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path (method boundary restored)" -ForegroundColor Green

  Write-Host "`nPROOF (show updateLocal + deleteLocal headers):" -ForegroundColor Yellow
  Select-String -Path $path -Pattern 'void updateLocal|void deleteLocal' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit --no-pager diff (task_store.dart only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/services/task_store.dart

  Write-Host "`n✅ task_store.dart fixed." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
