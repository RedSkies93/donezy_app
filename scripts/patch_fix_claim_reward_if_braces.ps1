$ErrorActionPreference = "Stop"

function Die($m){ throw $m }
function Backup-File([string]$path) {
  if (!(Test-Path $path)) { Die "Missing file: $path" }
  $bak = "$path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $path $bak -Force
  Write-Host "Backup created: $bak" -ForegroundColor Cyan
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

try {
  $p1 = "lib/actions/awards/claim_reward_action.dart"
  Backup-File $p1

  $lines = Get-Content $p1

  $target = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "if (!success)") { $target = $i; break }
  }
  if ($target -lt 0) { Die "Did not find exact line: if (!success)" }

  # Find the next non-empty line after the if; it must start with return const ActionResult.failure(
  $j = $target + 1
  while ($j -lt $lines.Count -and $lines[$j].Trim() -eq "") { $j++ }
  if ($j -ge $lines.Count) { Die "Unexpected EOF after if (!success)" }

  if ($lines[$j].Trim() -notlike "return const ActionResult.failure(*") {
    Die "Next statement after if (!success) was not the expected failure return. Found: $($lines[$j].Trim())"
  }

  $indentIf = ($lines[$target] -replace '^(\s*).*$','$1')
  $indentStmt = ($lines[$j] -replace '^(\s*).*$','$1')

  # Insert opening brace on the if line
  $lines[$target] = "${indentIf}if (!success) {"

  # Insert closing brace after the failure return completes (line that ends with ');')
  $end = -1
  for ($k=$j; $k -lt $lines.Count; $k++) {
    if ($lines[$k].Trim().EndsWith(");")) { $end = $k; break }
  }
  if ($end -lt 0) { Die "Could not find end of failure return (line ending with );)" }

  # Insert a closing brace line AFTER $end
  $before = @()
  if ($end -ge 0) { $before = $lines[0..$end] }
  $after = @()
  if ($end + 1 -le $lines.Count - 1) { $after = $lines[($end+1)..($lines.Count-1)] }

  $newLines = @()
  $newLines += $before
  $newLines += "${indentIf}}"
  $newLines += $after

  $out = ($newLines -join "`n") + "`n"
  WriteUtf8NoBom $p1 $out

  Write-Host "Patched braces: $p1" -ForegroundColor Green

  Write-Host "`nFormatting..." -ForegroundColor Yellow
  dart format $p1

  Write-Host "`nAnalyze..." -ForegroundColor Yellow
  flutter analyze

  Write-Host "`nDiff (claim only):" -ForegroundColor Yellow
  git --no-pager diff -- $p1

  Write-Host "`n✅ DONE" -ForegroundColor Green
}
catch {
  Write-Host "`n❌ PATCH FAILED:" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
}
finally {
  Read-Host "Press Enter to close"
}
