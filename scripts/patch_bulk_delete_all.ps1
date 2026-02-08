$ErrorActionPreference = "Stop"

function Backup-File($path) {
  $bak = "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  # ---------------------------------------------------------
  # 1) Patch ConfirmBulkDeleteAction: remove ".first" if present
  # ---------------------------------------------------------
  $path = "lib/actions/tasks/confirm_bulk_delete_action.dart"
  if (Test-Path $path) {
    Backup-File $path | Out-Null
    $s = Get-Content $path -Raw
    $orig = $s

    # If code does: service.deleteMany(selectedIds.first) -> service.deleteMany(selectedIds)
    $s = [regex]::Replace(
      $s,
      "(?m)(deleteMany\s*\(\s*)([A-Za-z_][A-Za-z0-9_]*)(?:Ids|TaskIds|SelectedIds)\s*\.first\s*(\)\s*;)",
      "`${1}`${2}Ids`${3}",
      1
    )

    # Broader: deleteMany(<anything>.first)
    $s = [regex]::Replace(
      $s,
      "(?m)(deleteMany\s*\(\s*)([A-Za-z_][A-Za-z0-9_]*(?:Ids|TaskIds|SelectedIds))\s*\.first\s*(\)\s*;)",
      "`${1}`${2}`${3}",
      1
    )

    if ($s -ne $orig) {
      Set-Content -Encoding UTF8 -Path $path -Value $s
      Write-Host "Patched: $path (deleteMany now receives ALL selected ids)" -ForegroundColor Green
    } else {
      Write-Host "No change in: $path (no .first bulk-delete call found)" -ForegroundColor Yellow
    }
  } else {
    Write-Host "Skip: not found $path" -ForegroundColor Yellow
  }

  # ---------------------------------------------------------
  # 2) Patch TaskService.deleteMany: await + snapshot
  # ---------------------------------------------------------
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  Backup-File $path | Out-Null
  $s = Get-Content $path -Raw
  $orig = $s

  # A) Fix async forEach (NOT awaited): taskIds.forEach((id) async { await ...; });
  $patternForEach = "(?s)taskIds\s*\.\s*forEach\s*\(\s*\(\s*(\w+)\s*\)\s*async\s*\{\s*([\s\S]*?)\s*\}\s*\)\s*;"
  if ($s -match $patternForEach) {
    $s = [regex]::Replace($s, $patternForEach, {
      param($m)
      $idVar = $m.Groups[1].Value
      $body  = $m.Groups[2].Value.TrimEnd()
      return "final ids = taskIds.toList(growable: false);`n    for (final $idVar in ids) {`n      $body`n    }"
    }, 1)
  }

  # B) Fix for-in over live Set: for (final id in taskIds) { ... }  (concurrent mod safe)
  $patternForIn = "(?m)^\s*for\s*\(\s*(?:final|var)\s+(\w+)\s+in\s+taskIds\s*\)\s*\{"
  if ($s -match $patternForIn) {
    # Only inject if we have not already converted to snapshot
    if ($s -notmatch "(?m)^\s*final\s+ids\s*=\s*taskIds\.toList") {
      $s = [regex]::Replace($s, $patternForIn, {
        param($m)
        $idVar = $m.Groups[1].Value
        return "    final ids = taskIds.toList(growable: false);`n    for (final $idVar in ids) {"
      }, 1)
    } else {
      $s = [regex]::Replace($s, $patternForIn, "    for (final `$1 in ids) {", 1)
    }
  }

  if ($s -ne $orig) {
    Set-Content -Encoding UTF8 -Path $path -Value $s
    Write-Host "Patched: $path (deleteMany now deletes ALL reliably)" -ForegroundColor Green
  } else {
    Write-Host "WARN: No deleteMany loop anchors matched in $path." -ForegroundColor Yellow
    Write-Host "Run the LOCATE command again and paste the deleteMany method block." -ForegroundColor Yellow
  }

  Write-Host "`n=== PROOF (deleteMany + callsite) ===" -ForegroundColor Cyan
  if (Test-Path "lib/actions/tasks/confirm_bulk_delete_action.dart") {
    Select-String -Path "lib/actions/tasks/confirm_bulk_delete_action.dart" -Pattern "deleteMany\(" -Context 0,6
  }
  Select-String -Path "lib/services/task_service.dart" -Pattern "Future<void>\s+deleteMany|taskIds\.forEach|final ids = taskIds\.toList|for\s*\(" -Context 0,8

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze

  Write-Host "`nNEXT:" -ForegroundColor Cyan
  Write-Host "1) Hot restart (press R in flutter run)" -ForegroundColor Cyan
  Write-Host "2) Select 5 tasks -> Bulk delete once -> ALL should disappear" -ForegroundColor Cyan
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force
  Write-Host "`nSTOPPED. Terminal will remain open." -ForegroundColor Red
}
finally {
  Read-Host "`nPress Enter to close"
}
