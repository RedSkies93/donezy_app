$ErrorActionPreference = "Stop"

$targets = @(
  "lib/screens/parent/parent_dashboard_page.dart",
  "lib/screens/child/child_dashboard_page.dart"
)

foreach ($p in $targets) {
  Write-Host "`n=== $p ===" -ForegroundColor Cyan
  $lines = Get-Content $p
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'child:\s*TaskCard\s*\(') {
      $start = [Math]::Max(0, $i-5)
      $end   = [Math]::Min($lines.Count-1, $i+70)
      for ($j=$start; $j -le $end; $j++) {
        "{0,4}: {1}" -f ($j+1), $lines[$j]
      }
    }
  }
}
