$ErrorActionPreference = "Stop"
Write-Host "=== RULES PATCH STARTED ===" -ForegroundColor Cyan

try {
  $path = "firestore.rules"
  if (!(Test-Path $path)) { throw "File not found: $path" }

  $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$path.bak_$ts"
  Copy-Item $path $bak -Force
  Write-Host ("Backup created: {0}" -f $bak) -ForegroundColor Cyan

  $lines = Get-Content $path
  $targets = @(158,164,178)

  foreach ($n in $targets) {
    if ($n -gt $lines.Count) { continue }

    $found = $null

    # Find the nearest enclosing chats wildcard above the target line:
    # match /parents/{parentUid}/chats/{<WILDCARD>}
    for ($i = $n; $i -ge [Math]::Max(1, $n - 120); $i--) {
      $m = [regex]::Match($lines[$i-1], 'match\s+/parents/\{parentUid\}/chats/\{([a-zA-Z_][a-zA-Z0-9_]*)\}')
      if ($m.Success) { $found = $m.Groups[1].Value; break }
    }

    if (-not $found) {
      Write-Host ("WARN: No chats match wildcard found above line {0}" -f $n) -ForegroundColor Yellow
      continue
    }

    # On the target line, if there is /chats/$(something), force it to /chats/$(<found>)
    $needle = [regex]::Match($lines[$n-1], '/chats/\$\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)')
    if (-not $needle.Success) {
      Write-Host ("INFO: Line {0} has no /chats/$() interpolation" -f $n) -ForegroundColor Yellow
      continue
    }

    $oldVar = $needle.Groups[1].Value
    if ($oldVar -ne $found) {
      $lines[$n-1] = [regex]::Replace(
        $lines[$n-1],
        '\$\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)',
        '$(' + $found + ')'
      )
      Write-Host ("Line {0}: $({1}) -> $({2})" -f $n, $oldVar, $found) -ForegroundColor Cyan
    } else {
      Write-Host ("Line {0}: already uses {1}" -f $n, $found) -ForegroundColor Green
    }
  }

  # Write back using the platform newline (avoids backtick parsing issues)
  Set-Content -Encoding UTF8 -Path $path -Value ($lines -join [Environment]::NewLine)

  Write-Host "" 
  Write-Host "=== Deploy rules/indexes ===" -ForegroundColor Cyan
  firebase deploy --only firestore:rules,firestore:indexes

  Write-Host "" 
  Write-Host "DONE" -ForegroundColor Green
}
catch {
  Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
  exit 1
}
