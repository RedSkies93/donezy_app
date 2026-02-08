$ErrorActionPreference = "Stop"

function Die($m){ throw $m }

try {
  $path = "lib/services/task_service.dart"
  if (!(Test-Path $path)) { Die "Missing file: $path" }

  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan

  # --- SHOW the exact problem area FIRST (what analyzer references)
  Write-Host "`n=== CONTEXT (lines 210-260) BEFORE ===" -ForegroundColor Yellow
  $lines = Get-Content $path
  $start = [Math]::Max(1, 210)
  $end   = [Math]::Min($lines.Count, 260)
  for ($i=$start; $i -le $end; $i++) {
    "{0,4}: {1}" -f $i, $lines[$i-1]
  }

  # --- FIX 1: remove any stray single-character token lines that can break parsing
  # (common after bad paste/regex ops: ":" or stray "@", etc.)
  $clean = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($ln -match '^\s*:\s*$') { continue }
    if ($ln -match '^\s*@\s*$') { continue }
    if ($ln -match '^\s*;+\s*$') { continue }
    $clean.Add($ln)
  }

  # --- FIX 2: ensure we don't end the file with multiple top-level "}" lines
  # Trim trailing blank lines first
  while ($clean.Count -gt 0 -and ($clean[$clean.Count-1] -match '^\s*$')) {
    $clean.RemoveAt($clean.Count-1)
  }

  # If there are multiple trailing braces, keep only ONE.
  $braceCount = 0
  for ($j=$clean.Count-1; $j -ge 0; $j--) {
    if ($clean[$j] -match '^\s*\}\s*$') { $braceCount++ } else { break }
  }
  if ($braceCount -gt 1) {
    $toRemove = $braceCount - 1
    for ($k=0; $k -lt $toRemove; $k++) {
      $clean.RemoveAt($clean.Count-1)
    }
    Write-Host "`nRemoved $toRemove extra trailing '}' brace line(s)." -ForegroundColor Green
  }

  # Write back
  $out = ($clean -join "`r`n") + "`r`n"
  Set-Content -Encoding UTF8 $path $out

  # --- PROOF after
  Write-Host "`n=== CONTEXT (lines 210-260) AFTER ===" -ForegroundColor Yellow
  $lines2 = Get-Content $path
  $end2   = [Math]::Min($lines2.Count, 260)
  for ($i=$start; $i -le $end2; $i++) {
    "{0,4}: {1}" -f $i, $lines2[$i-1]
  }

  Write-Host "`nRunning flutter analyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nGit diff:" -ForegroundColor Yellow
  git diff

  Write-Host "`n✅ task_service.dart parsing restored (if analyze is clean)." -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
