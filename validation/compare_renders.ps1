# Pixel-a-pixel comparison between the Delphi GDI+ baseline renders
# (baseline\png\*.png) and the Lazarus LCL backend renders
# (tests\lcl\lcl_renders\*.bmp). Part of Phase 5.1 validation.
#
# Usage:
#   pwsh -File compare_renders.ps1 [-BaselineDir ..\..\baseline\png]
#                                  [-LclDir ..\..\tests\lcl\lcl_renders]
#                                  [-OutDir ..\report]
#
# Per-pixel buckets:
#   exact : R,G,B all identical
#   near  : max channel deviation <= $TolNear
#   far   : otherwise
#
# Classification per SVG:
#   IDENTICAL  : exact == 100%
#   NEAR       : exact+near >= 99.5%
#   DIVERGENT  : otherwise (AA edges, text, radial gradient, ...)

param(
  [string]$BaselineDir = '',
  [string]$LclDir = '',
  [string]$OutDir = '',
  [switch]$DiffImages
)

$Root    = Split-Path -Parent $PSScriptRoot
if (-not $BaselineDir) { $BaselineDir = Join-Path $Root 'baseline\png' }
if (-not $LclDir)      { $LclDir      = Join-Path $Root 'tests\lcl\lcl_renders' }
if (-not $OutDir)      { $OutDir      = Join-Path $Root 'validation\report' }

$TolNear = 32

Add-Type -AssemblyName System.Drawing

function Get-24bpp([System.Drawing.Bitmap]$Src) {
  $bmp = New-Object System.Drawing.Bitmap($Src.Width, $Src.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  try {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try { $g.Clear([System.Drawing.Color]::White); $g.DrawImage($Src, 0, 0, $Src.Width, $Src.Height) }
    finally { $g.Dispose() }
  } catch { $bmp.Dispose(); throw }
  return $bmp
}

function Compare-Pair([string]$name, [string]$baseFile, [string]$lclFile, [string]$diffDir) {
  $b1 = [System.Drawing.Bitmap]::FromFile($baseFile)
  $b2 = [System.Drawing.Bitmap]::FromFile($lclFile)
  try {
    if (($b1.Width -ne $b2.Width) -or ($b1.Height -ne $b2.Height)) {
      return [pscustomobject]@{ Name = $name; Status = 'SIZE MISMATCH'; Width = "$($b1.Width)x$($b1.Height)"; Height = ''; Exact = 0.0; Near = 0.0; Far = 0.0; MaxDev = -1 }
    }
    $a = Get-24bpp $b1
    $c = Get-24bpp $b2
    try {
      $w = $a.Width; $h = $a.Height
      $da = $a.LockBits([System.Drawing.Rectangle]::new(0,0,$w,$h), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
      $dc = $c.LockBits([System.Drawing.Rectangle]::new(0,0,$w,$h), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
      $dimg = $null; $dd = $null; $bd = $null; $sd = 0
      try {
        if ($diffDir) {
          $dimg = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
          $dd = $dimg.LockBits([System.Drawing.Rectangle]::new(0,0,$w,$h), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
          $sd = $dd.Stride
          $bd = New-Object byte[] ($sd * $h)
        }
        $sa = $da.Stride; $sc = $dc.Stride
        $ba = New-Object byte[] ($sa * $h); [System.Runtime.InteropServices.Marshal]::Copy($da.Scan0, $ba, 0, $ba.Length)
        $bc = New-Object byte[] ($sc * $h); [System.Runtime.InteropServices.Marshal]::Copy($dc.Scan0, $bc, 0, $bc.Length)
        $exact = [long]0; $near = [long]0; $far = [long]0; $maxDev = 0
        for ($y = 0; $y -lt $h; $y++) {
          $pa = $sa * $y; $pc = $sc * $y; $pd = $sd * $y
          for ($x = 0; $x -lt $w; $x++) {
            $i = $pa + $x * 3; $j = $pc + $x * 3
            $d = [Math]::Max([Math]::Abs([int]$ba[$i]   - [int]$bc[$j]),
                 [Math]::Max([Math]::Abs([int]$ba[$i+1] - [int]$bc[$j+1]),
                             [Math]::Abs([int]$ba[$i+2] - [int]$bc[$j+2])))
            if ($d -gt $maxDev) { $maxDev = $d }
            if ($bd) {
              # diff image: gray = exact, yellow = near, red = far (BGR order)
              $k = $pd + $x * 3
              if ($d -eq 0)          { $bd[$k]=128; $bd[$k+1]=128; $bd[$k+2]=128 }
              elseif ($d -le $TolNear) { $bd[$k]=0;   $bd[$k+1]=255; $bd[$k+2]=255 }
              else                   { $bd[$k]=0;   $bd[$k+1]=0;   $bd[$k+2]=255 }
            }
            if    ($d -eq 0)            { $exact++ }
            elseif ($d -le $TolNear)    { $near++ }
            else                        { $far++ }
          }
        }
        if ($dimg) {
          [System.Runtime.InteropServices.Marshal]::Copy($bd, 0, $dd.Scan0, $bd.Length)
          $dimg.UnlockBits($dd)
          $diffPath = Join-Path $diffDir ($name + '.diff.png')
          $dimg.Save($diffPath, [System.Drawing.Imaging.ImageFormat]::Png)
          $dimg.Dispose()
        }
        $tot = $exact + $near + $far
        $exactP = if ($tot) { 100.0 * $exact / $tot } else { 0 }
        $nearP  = if ($tot) { 100.0 * $near  / $tot } else { 0 }
        $farP   = if ($tot) { 100.0 * $far   / $tot } else { 0 }
        $fidel = $exactP + $nearP
        if    ($exactP -ge 100.0)        { $status = 'IDENTICAL' }
        elseif ($fidel -ge 99.5)         { $status = 'NEAR' }
        else                             { $status = 'DIVERGENT' }
        return [pscustomobject]@{ Name = $name; Status = $status; Width = "$($b1.Width)x$($b1.Height)"; Height = ''; Exact = $exactP; Near = $nearP; Far = $farP; MaxDev = $maxDev }
      } finally {
        $a.UnlockBits($da); $c.UnlockBits($dc)
      }
    } finally { $a.Dispose(); $c.Dispose() }
  } finally {
    $b1.Dispose(); $b2.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $BaselineDir)) { Write-Error "Baseline dir not found: $BaselineDir"; exit 1 }
if (-not (Test-Path -LiteralPath $LclDir))      { Write-Error "LCL render dir not found: $LclDir"; exit 1 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$baseFiles = Get-ChildItem -LiteralPath $BaselineDir -Filter *.png
$diffDir = $null
if ($DiffImages) { $diffDir = Join-Path $OutDir 'diff'; New-Item -ItemType Directory -Force -Path $diffDir | Out-Null }
$results = @()
foreach ($bf in $baseFiles) {
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($bf.Name)
  $lclFile = Join-Path $LclDir ($baseName + '.bmp')
  if (-not (Test-Path -LiteralPath $lclFile)) {
    $results += [pscustomobject]@{ Name = $baseName; Status = 'NO LCL RENDER'; Width = ''; Height = ''; Exact = 0.0; Near = 0.0; Far = 0.0; MaxDev = -1 }
  } else {
    $results += Compare-Pair $baseName $bf.FullName $lclFile $diffDir
  }
}

$outFile = Join-Path $OutDir 'compare_report.txt'
$csvFile = Join-Path $OutDir 'fidelity.csv'
$csv = @('name,status,size,exact,near,far,maxdev')
$inv = [System.Globalization.CultureInfo]::InvariantCulture
foreach ($r in $results) {
  $csv += ('{0},{1},{2},{3},{4},{5},{6}' -f $r.Name, $r.Status, $r.Width,
           $r.Exact.ToString('0.0000', $inv), $r.Near.ToString('0.0000', $inv),
           $r.Far.ToString('0.0000', $inv), $r.MaxDev)
}
$csv | Set-Content -LiteralPath $csvFile -Encoding UTF8
$lines = @("DelphiSVG pixel-a-pixel report (GDI+ baseline vs LCL backend) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$lines += ('bucket definitions: exact=all channels equal; near=max channel dev<={0}; far otherwise' -f $TolNear)
$lines += 'status: IDENTICAL exact==100%; NEAR exact+near>=99.5%; DIVERGENT otherwise'
$lines += ''
$lines += ('{0,-28} {1,-13} {2,10} {3,9} {4,9} {5,9} {6,7}' -f 'SVG', 'Status', 'Size', 'Exact%', 'Near%', 'Far%', 'MaxDev')
$lines += ('{0,-28} {1,-13} {2,10} {3,9} {4,9} {5,9} {6,7}' -f ('-'*28), ('-'*13), ('-'*10), ('-'*9), ('-'*9), ('-'*9), ('-'*7))
$cnt = @{ IDENTICAL = 0; NEAR = 0; DIVERGENT = 0 }
$sumExact = [double]0; $sumFidel = [double]0; $cmp = 0
foreach ($r in $results) {
  $lines += ('{0,-28} {1,-13} {2,10} {3,9:N2} {4,9:N2} {5,9:N2} {6,7}' -f $r.Name, $r.Status, $r.Width, $r.Exact, $r.Near, $r.Far, $r.MaxDev)
  if ($cnt.ContainsKey($r.Status)) { $cnt[$r.Status]++; }
  if (($r.Status -eq 'IDENTICAL') -or ($r.Status -eq 'NEAR') -or ($r.Status -eq 'DIVERGENT')) {
    $cmp++; $sumExact += $r.Exact; $sumFidel += ($r.Exact + $r.Near)
  }
}
$lines += ''
$lines += 'Compared: {0}  Identical: {1}  Near: {2}  Divergent: {3}' -f $cmp, $cnt.IDENTICAL, $cnt.NEAR, $cnt.DIVERGENT
if ($cmp) {
  $lines += 'Avg exact: {0:0.00}%   Avg fidelity (exact+near): {1:0.00}%' -f ($sumExact/$cmp), ($sumFidel/$cmp)
}
if ($diffDir) {
  $n = (Get-ChildItem -LiteralPath $diffDir -Filter *.png).Count
  $lines += ('Diff images written: {0} -> {1}' -f $n, $diffDir)
}
$lines | Set-Content -LiteralPath $outFile -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }