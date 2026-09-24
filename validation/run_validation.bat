@echo off
rem ============================================================================
rem  DelphiSVG - validacao completa (Fase 5)
rem  Compila (Delphi dcc32 + FPC), renderiza, compara e gera relatorios em
rem  validation\report\. Requer: Delphi 12.2 + FPC 3.2.2 + pwsh no PATH.
rem  Uso: validation\run_validation.bat
rem ============================================================================
setlocal enabledelayedexpansion
set "ROOT=%~dp0.."
set "DCC=C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc32.exe"
set "FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe"
set "FPCUNIT=-Fu%ROOT%\src\svg -Fu%ROOT%\src\painter -Fu%ROOT%\src\gdip -Fu%ROOT%\Packages\Lazarus\components -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\rtl -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\win32 -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\vcl-compat -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\lcl\units\x86_64-win64\win32 -FuC:\lazarus\lcl\units\x86_64-win64 -FuC:\lazarus\components\lazutils\lib\x86_64-win64"

echo [1/5] Baseline Delphi (GDI+) -> baseline\png
pushd "%ROOT%\baseline"
del /q *.dcu 2>nul
"%DCC%" -B -CC -U"..\src\svg;..\src\gdip;..\src\painter" RenderBaseline.dpr
if errorlevel 1 goto :fail
del /q png\*.png 2>nul
RenderBaseline.exe
if errorlevel 1 goto :fail
popd

echo [2/5] Renders LCL -> tests\lcl\lcl_renders
call "%ROOT%\tests\lcl\run_lclrenders.bat"
if errorlevel 1 goto :fail

echo [3/5] Comparacao pixel-a-pixel
pwsh -NoProfile -File "%ROOT%\validation\compare_renders.ps1" -DiffImages
if errorlevel 1 goto :fail

echo [4/5] Integracao (Delphi + Lazarus)
mkdir out 2>nul
pushd "%ROOT%\validation\integration"
"%DCC%" -B -CC -U"..\..\src\svg;..\..\src\gdip;..\..\src\painter" IntegrationDelphi.dpr
if errorlevel 1 goto :fail
popd
"%FPC%" -Mdelphi %FPCUNIT% -FUout -o"%ROOT%\tests\lcl\LCLIntegrate.exe" "%ROOT%\tests\lcl\LCLIntegrate.lpr"
if errorlevel 1 goto :fail
pushd "%ROOT%\validation\integration"
del /q "..\report\integration_*.csv" "..\report\integration_report.txt" 2>nul
IntegrationDelphi.exe
if errorlevel 1 goto :fail
popd
pushd "%ROOT%\tests\lcl"
LCLIntegrate.exe "..\..\validation\report\integration_lcl.csv"
if errorlevel 1 goto :fail
popd
pwsh -NoProfile -File "%ROOT%\validation\compare_integration.ps1"
if errorlevel 1 goto :fail

echo [5/5] Performance + memoria
pushd "%ROOT%\validation\perf"
mkdir out 2>nul
"%DCC%" -B -CC -U"..\..\src\svg;..\..\src\gdip;..\..\src\painter" PerfTest.dpr
if errorlevel 1 goto :fail
"%FPC%" -Mdelphi %FPCUNIT% -FUout -o"%ROOT%\tests\lcl\PerfTestLCL.exe" "%ROOT%\tests\lcl\PerfTestLCL.lpr"
if errorlevel 1 goto :fail
popd
pwsh -NoProfile -File "%ROOT%\validation\run_perf.ps1"
if errorlevel 1 goto :fail

echo.
echo OK - relatorios em validation\report\
exit /b 0

:fail
echo.
echo FALHOU - veja a saida acima
exit /b 1