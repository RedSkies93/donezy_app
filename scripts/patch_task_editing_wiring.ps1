$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  # ------------------------------------------------------------
  # 0) task_service.dart — remove stray ":" line (cosmetic, but keep clean)
  # ------------------------------------------------------------
  $path = "lib/services/task_service.dart"
  Backup-File $path
  $s = Get-Content $path -Raw
  $s2 = [regex]::Replace($s, '(?m)^\s*:\s*$\r?\n?', '')
  if ($s2 -ne $s) {
    Set-Content -Encoding UTF8 $path $s2
    Write-Host "Cleaned stray ':' line in: $path" -ForegroundColor Green
  } else {
    Write-Host "No stray ':' line found in: $path (ok)" -ForegroundColor DarkGray
  }

  # ------------------------------------------------------------
  # 1) edit_task_action.dart — ensure edit uses TaskService methods (title/points/due)
  # ------------------------------------------------------------
  $path = "lib/actions/tasks/edit_task_action.dart"
  Backup-File $path
  $s = Get-Content $path -Raw

  # Ensure we call the service methods that preserve childId (service uses copyWith)
  # Replace any direct update call with these three calls.
  $pattern = '(?ms)await\s+taskService\.[a-zA-Z0-9_]+\s*\([\s\S]*?\);\s*(?:taskStore\.[a-zA-Z0-9_]+\s*\([\s\S]*?\);\s*)?'
  $replacement = @"
await taskService.rename(task.id, updated.title);
await taskService.setPointsValue(task.id, updated.pointsValue);
await taskService.setDueDate(task.id, updated.dueDate);
"@

  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)
  if ($s2 -eq $s) {
    Write-Host "No matching edit call block replaced in $path (will not force changes)." -ForegroundColor DarkGray
  } else {
    Set-Content -Encoding UTF8 $path $s2
    Write-Host "Patched: $path (edit now routes through TaskService rename/setPoints/setDueDate)" -ForegroundColor Green
  }

  # ------------------------------------------------------------
  # 2) task_edit_dialog.dart — ensure it returns updated TaskModel (title/pointsValue/dueDate)
  # ------------------------------------------------------------
  $path = "lib/widgets/tasks/task_edit_dialog.dart"
  Backup-File $path
  $s = Get-Content $path -Raw

  # Normalize fields: pointsValue, dueDate, preserve childId
  $pattern = '(?ms)final\s+updated\s*=\s*task\.copyWith\s*\([\s\S]*?\);\s*'
  $replacement = @"
final updated = task.copyWith(
  title: titleController.text.trim(),
  pointsValue: int.tryParse(pointsController.text.trim()) ?? task.pointsValue,
  dueDate: selectedDueDate,
  // DO NOT touch childId
);
"@

  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)
  if ($s2 -eq $s) {
    Write-Host "No matching 'final updated = task.copyWith(...)' found in $path (skipped)." -ForegroundColor DarkGray
  } else {
    Set-Content -Encoding UTF8 $path $s2
    Write-Host "Patched: $path (updated TaskModel uses pointsValue + dueDate, preserves childId)" -ForegroundColor Green
  }

  # ------------------------------------------------------------
  # VERIFICATION
  # ------------------------------------------------------------
  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ Task Editing wiring patch applied." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
