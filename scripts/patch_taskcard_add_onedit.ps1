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
  # FILE: lib/widgets/tasks/task_card.dart
  # ------------------------------------------------------------
  $path = "lib/widgets/tasks/task_card.dart"
  Backup-File $path

  $s = Get-Content $path -Raw

  # 1) Ensure the file imports EditTaskAction (and BuildContext is available)
  if ($s -notmatch "edit_task_action\.dart") {
    # try to place near other task action imports
    $s = $s -replace "(?m)^(import\s+'.*?/actions/tasks/[^']+'\s*;\s*)$",
      "`$1`r`nimport '../../actions/tasks/edit_task_action.dart';"
  }
  # If that didn't insert (no matching actions import block), insert after flutter/material.dart
  if ($s -notmatch "edit_task_action\.dart") {
    $s = $s -replace "(?m)^(import\s+'package:flutter/[^']+'\s*;\s*)",
      "`$1`r`nimport '../../actions/tasks/edit_task_action.dart';"
  }

  # 2) Add optional onEdit callback field to constructor + class fields
  # We will:
  #   - add: final VoidCallback? onEdit;
  #   - add param in constructor: this.onEdit,
  #
  # Add field (only if missing)
  if ($s -notmatch "(?m)^\s*final\s+VoidCallback\?\s+onEdit\s*;") {
    # Insert after other final fields (best-effort: after "final TaskModel task;" or similar)
    $s = $s -replace "(?m)^\s*final\s+TaskModel\s+task\s*;\s*$",
      "  final TaskModel task;`r`n  final VoidCallback? onEdit;"
  }

  # Add constructor param (only if missing)
  if ($s -notmatch "(?m)^\s*this\.onEdit\s*,\s*$") {
    # Insert into the const TaskCard({ ... }) parameter list just before closing })
    $s = [regex]::Replace(
      $s,
      "(?ms)(const\s+TaskCard\s*\(\s*\{\s*)([\s\S]*?)(\}\s*\)\s*;)",
      {
        param($m)
        $head = $m.Groups[1].Value
        $body = $m.Groups[2].Value
        $tail = $m.Groups[3].Value

        if ($body -match "(?m)^\s*this\.onEdit\s*,\s*$") { return $m.Value }

        # Add near other callbacks if present, else at end
        $insert = "    this.onEdit,`r`n"
        $newBody = $body + $insert
        return $head + $newBody + $tail
      },
      1
    )
  }

  # 3) Wire an edit trigger inside build():
  # We will add a small IconButton that calls:
  #   onEdit?.call() ?? EditTaskAction().run(context, task: task);
  #
  # We need to locate a Row near the title area; if we can't, we fall back
  # to wrapping the whole card with InkWell onLongPress as edit.
  $didWire = $false

  # Try to inject an edit IconButton into a Row(...) that contains the title text.
  if ($s -match "(?ms)Row\s*\(\s*children\s*:\s*\[[\s\S]{0,600}?Text\(") {
    $s2 = [regex]::Replace(
      $s,
      "(?ms)(Row\s*\(\s*children\s*:\s*\[\s*)([\s\S]*?)(\]\s*\)\s*,)",
      {
        param($m)
        $prefix = $m.Groups[1].Value
        $kids   = $m.Groups[2].Value
        $suffix = $m.Groups[3].Value

        if ($kids -match "Icons\.edit") { return $m.Value }

        $editBtn = @"
Expanded(child:
"@

        # Only inject if there isn't already Expanded wrapping first child;
        # if not safe, we won't restructure. We'll just append an IconButton.
        $injection = @"
IconButton(
  tooltip: 'Edit task',
  icon: const Icon(Icons.edit),
  onPressed: () {
    if (onEdit != null) {
      onEdit!();
    } else {
      EditTaskAction().run(context, task: task);
    }
  },
),
"@

        $newKids = $kids + "`r`n" + $injection
        return $prefix + $newKids + $suffix
      },
      1
    )
    if ($s2 -ne $s) {
      $s = $s2
      $didWire = $true
    }
  }

  # Fallback: add InkWell onLongPress to outermost card container if we couldn't inject button
  if (-not $didWire) {
    # Find "return" of build and wrap the returned widget with InkWell
    # Best-effort: replace "return " with "return InkWell(... child: "
    if ($s -match "(?m)^\s*return\s+") {
      $s = [regex]::Replace(
        $s,
        "(?m)^\s*return\s+",
@"
    return InkWell(
      onLongPress: () {
        if (onEdit != null) {
          onEdit!();
        } else {
          EditTaskAction().run(context, task: task);
        }
      },
      child: 
"@,
        1
      )

      # Close InkWell before the first semicolon ending the return statement (best-effort)
      $s = [regex]::Replace($s, "(?ms)(;\s*)$", "`r`n    );`r`n`$1", 1)
      $didWire = $true
    }
  }

  if (-not $didWire) { Die "Could not wire edit trigger in task_card.dart (no safe injection point found)." }

  Set-Content -Encoding UTF8 $path $s
  Write-Host "Patched: $path (onEdit + EditTaskAction wiring)" -ForegroundColor Green

  Write-Host "`nPROOF (TaskCard onEdit + Icons.edit):" -ForegroundColor Yellow
  Select-String -Path $path -Pattern "onEdit|EditTaskAction|Icons\.edit|onLongPress" | Select-Object -First 50 |
    ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }

  # ------------------------------------------------------------
  # VERIFICATION
  # ------------------------------------------------------------
  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff (task_card.dart only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/widgets/tasks/task_card.dart

  Write-Host "`n✅ TaskCard edit is now available (tap pencil OR long-press fallback)." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
