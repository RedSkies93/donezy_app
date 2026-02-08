$ErrorActionPreference = "Stop"

$roots = @(
  "lib/screens",
  "lib/widgets",
  "lib"
)

$dart = Get-ChildItem -Recurse -File -Path $roots -Filter *.dart -ErrorAction SilentlyContinue

$hits = @()
foreach ($f in $dart) {
  $lines = Get-Content $f.FullName
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\bTaskCard\s*\(') {
      # grab a small window to detect onEdit inside the call
      $win = ($lines[$i..([Math]::Min($i+40, $lines.Count-1))] -join "`n")
      if ($win -notmatch '\bonEdit\s*:') {
        $hits += [pscustomobject]@{
          File = $f.FullName
          Line = ($i+1)
          Snip = ($lines[$i]).Trim()
        }
      }
    }
  }
}

if ($hits.Count -eq 0) {
  Write-Host "✅ All TaskCard(...) callsites appear to include onEdit:" -ForegroundColor Green
} else {
  Write-Host "❌ Found TaskCard(...) callsites missing onEdit:" -ForegroundColor Red
  $hits | Format-Table -AutoSize
  Write-Host "`nPaste this output here and I will generate the exact minimal patch for YOUR current callsites." -ForegroundColor Yellow
}
