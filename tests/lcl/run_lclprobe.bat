@echo off
set FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
set BASE=D:\RecursosGitHub\DelphiSVG
set FPATH=-Fu"%BASE%\src\svg" -Fu"%BASE%\src\painter" -Fu"%BASE%\src\gdip" -Fu"%BASE%\Packages\Lazarus\components" -Fu"C:\lazarus\lcl\units\x86_64-win64\win32" -Fu"C:\lazarus\lcl\units\x86_64-win64" -Fu"C:\lazarus\components\lazutils\lib\x86_64-win64" -Fu"C:\lazarus\fpc\3.2.2\units\x86_64-win64"

%FPC% -Mdelphi -B -gl -Xg %FPATH% -o"%BASE%\tests\lcl\LCLProbe.exe" "%BASE%\tests\lcl\LCLProbe.lpr" 2>&1
echo ExitCode=%ERRORLEVEL%
if exist "%BASE%\tests\lcl\LCLProbe.exe" (
  cd /d %BASE%\tests\lcl
  LCLProbe.exe
)