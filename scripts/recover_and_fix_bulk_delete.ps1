$ErrorActionPreference = "Stop"

function Backup-File($path) {
  $bak = "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  # 0) Safety backup of CURRENT broken file
  Backup-File $path | Out-Null

  # 1) Pick a backup to restore:
  # Prefer the earlier known-good timestamp (074515) if it exists.
  $preferred = Get-ChildItem "lib/services/task_service.dart.bak_20260208_074515*" -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($preferred) {
    $restore = $preferred.FullName
  } else {
    # Otherwise pick the OLDEST backup (most likely pre-damage)
    $restore = Get-ChildItem "lib/services/task_service.dart.bak_*" -ErrorAction SilentlyContinue |
      Sort-Object Name |
      Select-Object -First 1 |
      ForEach-Object FullName
  }

  if (-not $restore) {
    throw "No backups found for task_service.dart (lib/services/task_service.dart.bak_*)"
  }

  Copy-Item $restore $path -Force
  Write-Host "RESTORED from: $restore" -ForegroundColor Green

  # 2) Apply a BRACE-SAFE patch: snapshot ids INSIDE deleteMany
  $s = Get-Content $path -Raw
  $orig = $s

  # Insert snapshot line right before the loop: "for (final id in ids) {"
  if ($s -match "(?m)^\s*final\s+idList\s*=\s*ids\.toList") {
    Write-Host "OK: snapshot already present (idList)." -ForegroundColor Yellow
  } else {
    $loopAnchor = "(?m)^(?<indent>\s*)for\s*\(\s*final\s+id\s+in\s+ids\s*\)\s*\{"
    if ($s -notmatch $loopAnchor) { throw "Anchor not found: for (final id in ids) {" }

    $nl = [Environment]::NewLine
    $s = [regex]::Replace($s, $loopAnchor, {
      param($m)
      $indent = $m.Groups["indent"].Value
      return ($indent + "final idList = ids.toList(growable: false);" + $nl + $m.Value.Replace(" in ids", " in idList"))
    }, 1)
  }

  # Ensure Firestore call uses the same snapshot
  $s = [regex]::Replace(
    $s,
    "(?m)^\s*await\s+_firestore!\.deleteMany\(_familyId,\s*ids\)\s*;\s*$",
    "      await _firestore!.deleteMany(_familyId, idList.toSet());",
    1
  )

  if ($s -ne $orig) {
    Set-Content -Encoding UTF8 -Path $path -Value $s
    Write-Host "PATCHED: deleteMany now snapshots ids safely" -ForegroundColor Green
  } else {
    Write-Host "No changes applied (already patched?)" -ForegroundColor Yellow
  }

  Write-Host "`n=== PROOF (deleteMany) ===" -ForegroundColor Cyan
  Select-String -Path $path -Pattern "Future<void>\s+deleteMany|final idList|for \(final id in idList\)|deleteMany\(_familyId" -Context 0,6

  Write-Host "`n=== flutter analyze ===" -ForegroundColor Cyan
  flutter analyze
}
catch {
  Write-Host "`nERROR (copy/paste this):" -ForegroundColor Red
  $_ | Format-List * -Force
}
finally {
  Read-Host "`nPress Enter to close"
}
