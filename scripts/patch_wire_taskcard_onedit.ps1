$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function Ensure-Import([string]$path, [string]$importLine) {
  $s = Get-Content $path -Raw
  if ($s -match [regex]::Escape($importLine)) { return $s }

  # Insert after the last import line.
  $lines = Get-Content $path
  $lastImport = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*import\s+''') { $lastImport = $i }
  }
  if ($lastImport -lt 0) { Die "No import section found in $path" }

  $newLines = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Count; $i++) {
    $newLines.Add($lines[$i])
    if ($i -eq $lastImport) {
      $newLines.Add($importLine)
    }
  }
  return ($newLines -join "`r`n")
}

function Wire-TaskCard-OnEdit([string]$path) {
  Backup-File $path
  $s0 = Get-Content $path -Raw

  # Ensure EditTaskAction import exists (relative from screens/*/*.dart)
  $importLine = "import '../../actions/tasks/edit_task_action.dart';"
  $s = Ensure-Import $path $importLine

  # Replace each TaskCard(...) block that is missing onEdit:
  # - Extract the exact expression used in "task: <expr>"
  # - Insert: onEdit: () => EditTaskAction().run(context, task: <expr>),
  $rx = [regex]::new("(?ms)TaskCard\s*\(\s*(?<args>.*?)\)", "Multiline")

  $changed = $false
  $s2 = $rx.Replace($s, {
    param($m)

    $args = $m.Groups["args"].Value

    if ($args -match "(?m)\bonEdit\s*:") {
      return $m.Value
    }

    # capture task: <expr>
    $mTask = [regex]::Match($args, "(?m)\btask\s*:\s*(?<expr>[^,\r\n\)]+)")
    if (-not $mTask.Success) {
      return $m.Value  # don't touch if we can't safely find task:
    }

    $expr = $mTask.Groups["expr"].Value.Trim()

    # Insert onEdit after the task: line (right after that match)
    $args2 = [regex]::Replace(
      $args,
      "(?m)(\btask\s*:\s*" + [regex]::Escape($expr) + "\s*,?\s*$)",
      "`$1`r`n    onEdit: () => EditTaskAction().run(context, task: $expr),",
      1
    )

    if ($args2 -ne $args) { $script:changed = $true }
    return "TaskCard(`r`n    $args2`r`n  )"
  })

  if (-not $changed -and $s2 -eq $s0) {
    Write-Host "No TaskCard onEdit wiring changes needed in: $path" -ForegroundColor DarkGray
    return
  }

  Set-Content -Encoding UTF8 $path $s2
  Write-Host "Patched: $path (TaskCard.onEdit wired)" -ForegroundColor Green
}

try {
  $files = @(
    "lib/screens/parent/parent_dashboard_page.dart",
    "lib/screens/child/child_dashboard_page.dart"
  )

  foreach ($f in $files) {
    if (Test-Path $f) {
      Wire-TaskCard-OnEdit $f
    } else {
      Write-Host "Skip (missing): $f" -ForegroundColor DarkGray
    }
  }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nPROOF: TaskCard callsites now containing onEdit:" -ForegroundColor Yellow
  Get-ChildItem -Recurse -File -Path lib -Filter *.dart |
    Select-String -Pattern '\bTaskCard\s*\(' |
    ForEach-Object { "{0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }

  Write-Host "`nGit diff (dashboards only):" -ForegroundColor Yellow
  git --no-pager diff -- lib/screens/parent/parent_dashboard_page.dart lib/screens/child/child_dashboard_page.dart

  Write-Host "`n✅ onEdit wiring complete." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
