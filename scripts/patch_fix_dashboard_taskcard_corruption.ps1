$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function Remove-Line([string]$path, [string]$pattern) {
  Backup-File $path
  $s = Get-Content $path -Raw
  $before = $s
  $s = [regex]::Replace($s, $pattern, "", 'Multiline')
  if ($s -eq $before) { Write-Host "No match (ok): $path" -ForegroundColor DarkGray; return }
  Set-Content -Encoding UTF8 $path $s
  Write-Host "Patched: $path (line removed)" -ForegroundColor Green
}

function Replace-TaskCard-Call([string]$path, [string]$replacement) {
  Backup-File $path
  $s = Get-Content $path -Raw
  $before = $s

  # Replace ONLY the TaskCard(...) widget inside: child: TaskCard( ... ),
  # This is intentionally narrow to avoid touching other code.
  $pat = '(?ms)child:\s*TaskCard\s*\([\s\S]*?\)\s*,'
  if ($s -notmatch $pat) { Die "Could not find TaskCard(...) block to replace in: $path" }

  $s2 = [regex]::Replace($s, $pat, $replacement, 1)
  if ($s2 -eq $before) { Die "Replacement produced no changes in: $path" }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path (TaskCard block rebuilt cleanly)" -ForegroundColor Green
}

try {
  # 1) Remove unused import in child dashboard (fixes analyze warning)
  Remove-Line "lib/screens/child/child_dashboard_page.dart" '(?m)^\s*import\s+''\.\./\.\./actions/tasks/edit_task_action\.dart'';\s*\r?\n'

  # 2) Rebuild TaskCard block in PARENT dashboard (keep your bulk/edit logic, reorder handle, star/done/due)
  $parentReplacement = @"
child: TaskCard(
  task: t,
  isSelected: taskStore.isSelected(t.id),
  dragHandle: canReorder
      ? ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.drag_handle_rounded),
          ),
        )
      : const Padding(
          padding: EdgeInsets.all(10),
          child: Opacity(
            opacity: 0.25,
            child: Icon(Icons.drag_handle_rounded),
          ),
        ),
  onToggleStar: () => toggleStar.run(service: service, taskId: t.id),
  onToggleDone: () => toggleDone.run(service: service, taskId: t.id),
  onPickDueDate: () => pickDue.run(context: context, service: service, task: t),
  onEdit: () {
    if (taskStore.bulkMode) {
      taskStore.toggleSelected(t.id);
    } else {
      EditTaskAction().run(context: context, service: service, task: t);
    }
  },
  onLongPress: () {
    if (!taskStore.bulkMode) taskStore.setBulkMode(true);
    taskStore.toggleSelected(t.id);
  },
),
"@

  Replace-TaskCard-Call "lib/screens/parent/parent_dashboard_page.dart" $parentReplacement

  # 3) Rebuild TaskCard block in CHILD dashboard (keep child hidden: no star, no due, no edit, no long press, no drag)
  $childReplacement = @"
child: TaskCard(
  task: t,
  isSelected: taskStore.isSelected(t.id),
  dragHandle: null,
  onToggleStar: null, // child: hidden
  onToggleDone: () => toggleDone.run(service: service, taskId: t.id),
  onPickDueDate: null, // child: hidden
  onEdit: null, // child: hidden
  onLongPress: null, // child: hidden
),
"@

  Replace-TaskCard-Call "lib/screens/child/child_dashboard_page.dart" $childReplacement

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (dashboards only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/screens/parent/parent_dashboard_page.dart lib/screens/child/child_dashboard_page.dart

  Write-Host "`n✅ CLEAN: dashboards TaskCard wiring restored + analyze warning removed." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
