$ErrorActionPreference = "Stop"

Write-Host "`n=== HIT LIST: TODO/FIXME/placeholder/unimplemented/debug prints ===" -ForegroundColor Yellow

$regexes = @(
  "TODO",
  "FIXME",
  "XXX",
  "placeholder",
  "UnimplementedError",
  "throw\s+UnimplementedError",
  "print\(",
  "debugPrint\("
)

Get-ChildItem -Recurse -File -Path lib -Filter *.dart |
  ForEach-Object {
    $p = $_.FullName
    foreach ($r in $regexes) {
      Select-String -Path $p -Pattern $r -ErrorAction SilentlyContinue |
        ForEach-Object { "{0}:{1}  {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }
    }
  }

Write-Host "`n=== DONE ===" -ForegroundColor Green
Read-Host "Press Enter to close"
