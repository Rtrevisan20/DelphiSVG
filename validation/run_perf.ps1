# Phase 5.3 driver: runs the Delphi (GDI+) and Lazarus (LCL) performance
# harnesses, samples each process working set during the run, and merges the
# timing CSVs into a comparison report (validation\report\perf_report.txt).
#
# Usage:
#   pwsh -File run_perf.ps1 [-ExeDir .] [-InDir ..\report]

param([string]$ExeDir = '', [string]$InDir = '')

$Root = $PSScriptRoot
if (-not $ExeDir) { $ExeDir = Join-Path $Root 'perf' }
if (-not $InDir)  { $InDir  = Join-Path $Root 'report' }
if (-not (Test-Path $InDir)) { New-Item -ItemType Directory -Force -Path $InDir | Out-Null }

$report = Join-Path $InDir 'perf_report.txt'
$lines = @(
  "DelphiSVG performance report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
  'Runs: Delphi PerfTest.exe (GDI+) vs Lazarus PerfTestLCL.exe (TPainterLCL)',
  'load_ms = parse+tree; best/avg_ms = 5 renders of the same painted canvas',
  ''
)

function Run-And-Sample($ExePath, $WorkDir, $OutPath) {
  $p = Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir -ArgumentList $OutPath -PassThru -NoNewWindow -RedirectStandardOutput "$OutPath.stdout.txt"
  $peak = [long]0
  while (-not $p.HasExited) {
    $p.Refresh()
    if ($p.WorkingSet64 -gt $peak) { $peak = $p.WorkingSet64 }
    Start-Sleep -Milliseconds 20
  }
  $p.WaitForExit()
  return [pscustomobject]@{ PeakKB = [math]::Round($peak / 1024) }
}

$dExe = Join-Path $ExeDir 'PerfTest.exe'
$lExe = Join-Path $ExeDir 'PerfTestLCL.exe'
$lWorkDir = Join-Path (Split-Path -Parent $Root) 'lazarus\examples'
$dCsv = Join-Path $InDir 'perf_delphi.csv'
$lCsv = Join-Path $InDir 'perf_lcl.csv'

Write-Output "Running Delphi harness..."
$d = Run-And-Sample $dExe $ExeDir $dCsv
Write-Output "Running LCL harness..."
$l = Run-And-Sample $lExe $lWorkDir $lCsv

$delphi = @{}
foreach ($r in (Import-Csv $dCsv)) { $delphi[$r.name] = $r }
$lcl = @{}
foreach ($r in (Import-Csv $lCsv)) { $lcl[$r.name] = $r }

$names = @($delphi.Keys + $lcl.Keys | Sort-Object -Unique)

$lines += '{0,-28} {1,9} {2,9} {3,9} {4,9} {5,9} {6,9} {7,10}' -f 'SVG','W','H','load(D)','load(L)','avg(D)','avg(L)','LCL/D avg x'
$lines += ('-' * 100)

$tot = @{ loadD = 0.0; loadL = 0.0; avgD = 0.0; avgL = 0.0 }
foreach ($n in $names) {
  $dd = $delphi[$n]; $ll = $lcl[$n]
  if (-not $dd -or -not $ll) { continue }
  $ld = [double]$dd.load_ms; $ll_ = [double]$ll.load_ms
  $ad = [double]$dd.avg_ms; $al = [double]$ll.avg_ms
  $tot.loadD += $ld; $tot.loadL += $ll_; $tot.avgD += $ad; $tot.avgL += $al
  $ratio = if ($ad -gt 0) { $al / $ad } else { [double]::NaN }
  $ratios = if ([double]::IsNaN($ratio)) { 'n/a' } else { ('{0:N2}x' -f $ratio) }
  $lines += '{0,-28} {1,9} {2,9} {3,9:N1} {4,9:N1} {5,9:N2} {6,9:N2} {7,10}' -f $n, $dd.w, $dd.h, $ld, $ll_, $ad, $al, $ratios
}

$lines += ('-' * 100)
$lines += ('{0,-28} {1,9} {2,9} {3,9:N1} {4,9:N1} {5,9:N2} {6,9:N2} {7,10}' -f 'TOTAL', '', '', $tot.loadD, $tot.loadL, $tot.avgD, $tot.avgL, ('{0:N2}x' -f ($tot.avgL / $tot.avgD)))
$lines += ''
$lines += ('Peak working set (whole suite):  Delphi {0} KB   LCL {1} KB' -f $d.PeakKB, $l.PeakKB)
$lines += ('Memory ratio LCL/Delphi: {0:N2}x' -f ($l.PeakKB / $d.PeakKB))
$lines += ''
$lines += 'Notes: working set sampled during the whole run (includes process/RTL/GDI+ base)'
$lines += '  - absolute numbers are NOT apples-to-apples; use as order-of-magnitude signal.'

$lines | Set-Content -LiteralPath $report -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }