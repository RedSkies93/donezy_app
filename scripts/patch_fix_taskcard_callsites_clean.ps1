$ErrorActionPreference = "Stop"

function Die($m){ throw $m }

function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function Replace-First([string]$path, [string]$pattern, [string]$replacement) {
  Backup-File $path
  $s = Get-Content $path -Raw
  if ($s -notmatch $pattern) { Die "Pattern not found in: $path" }
  $s2 = [regex]::Replace($s, $pattern, $replacement, 1)
  if ($s2 -eq $s) { Die "No change produced for: $path" }
  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path" -ForegroundColor Green
}

try {
  # ------------------------------------------------------------
  # 1) Parent Dashboard: replace the TaskCard(...) block (same logic, fixed indent)
  # ------------------------------------------------------------
  $parent = "lib/screens/parent/parent_dashboard_page.dart"
  $parentPat = '(?ms)child:\s*TaskCard\s*\([\s\S]*?\)\s*,\s*\r?\n\s*\)\s*,\s*\r?\n\s*\);\s*\r?\n'
  $parentRep = @"
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
),
);
"@
  Replace-First $parent $parentPat $parentRep

  # ------------------------------------------------------------
  # 2) Child Dashboard: replace the TaskCard(...) block (keep child hidden)
  # ------------------------------------------------------------
  $child = "lib/screens/child/child_dashboard_page.dart"
  $childPat = '(?ms)child:\s*TaskCard\s*\([\s\S]*?\)\s*,\s*\r?\n\s*\)\s*,\s*\r?\n\s*\);\s*\r?\n'
  $childRep = @"
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
),
);
"@
  Replace-First $child $childPat $childRep

  Write-Host "`nPROOF: show TaskCard blocks (first line only)..." -ForegroundColor Yellow
  Select-String -Path $parent,$child -Pattern 'child:\s*TaskCard\(' | ForEach-Object { "{0}:{1}  {2}" -f $_.Path,$_.LineNumber,$_.Line.Trim() }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (dashboards only):" -ForegroundColor Yellow
  git --no-pager diff -- $parent $child

  Write-Host "`n✅ OK: TaskCard callsites cleaned (parent + child)." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
