# Cross-checks the Phase 5.2 integration CSVs produced by the Delphi
# (IntegrationDelphi.dpr, GDI+) and Lazarus (LCLIntegrate.lpr, TPainterLCL)
# harnesses. Verifies that every example SVG loads and renders on both sides
# with consistent object counts and dimensions.
#
# Usage:
#   pwsh -File compare_integration.ps1 [-InDir ..\report]

param([string]$InDir = '')

$Root = $PSScriptRoot
if (-not $InDir) { $InDir = Join-Path $PSScriptRoot 'report' }

$dpath = Join-Path $InDir 'integration_delphi.csv'
$lpath = Join-Path $InDir 'integration_lcl.csv'
if (-not (Test-Path $dpath)) { Write-Error "Not found: $dpath"; exit 1 }
if (-not (Test-Path $lpath)) { Write-Error "Not found: $lpath"; exit 1 }

$delphi = @{}
foreach ($row in (Import-Csv $dpath)) { $delphi[$row.name] = $row }
$lcl = @{}
foreach ($row in (Import-Csv $lpath)) { $lcl[$row.name] = $row }

$names = @($delphi.Keys + $lcl.Keys | Sort-Object -Unique)

$out = @("DelphiSVG integration report (Delphi GDI+ vs Lazarus LCL) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$out += 'checks per SVG: load ok (both), render ok (both), object count equal, W/H equal'
$out += ''

$issues = @()
$ok = 0
foreach ($n in $names) {
  $d = $delphi[$n]
  $l = $lcl[$n]
  $problems = @()
  if (-not $d) { $problems += 'missing in Delphi' }
  if (-not $l) { $problems += 'missing in LCL' }
  if ($d -and $l) {
    if (($d.load -ne 'True') -or ($l.load -ne 'True')) { $problems += 'load failed' }
    if (($d.render -ne 'True') -or ($l.render -ne 'True')) { $problems += 'render failed' }
    if ($d.count -ne $l.count) { $problems += "count $($d.count) vs $($l.count)" }
    if (($d.w -ne $l.w) -or ($d.h -ne $l.h)) { $problems += "size $($d.w)x$($d.h) vs $($l.w)x$($l.h)" }
    if ($problems.Count -eq 0) {
      $ok++
      $out += ('{0,-28} OK   count={1} size={2}x{3}' -f $n, $d.count, $d.w, $d.h)
    } else {
      $out += ('{0,-28} FAIL {1}' -f $n, ($problems -join '; '))
      $issues += $n
    }
  } else {
    $out += ('{0,-28} FAIL {1}' -f $n, ($problems -join '; '))
    $issues += $n
  }
}

$out += ''
$out += ('Total: {0}   OK: {1}   Fail: {2}' -f $names.Count, $ok, $issues.Count)
$name = 'integration_report.txt'
$report = Join-Path $InDir $name
$out | Set-Content -LiteralPath $report -Encoding UTF8
$out | ForEach-Object { Write-Output $_ }