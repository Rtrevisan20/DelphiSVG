@echo off
set FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
set BASE=D:\RecursosGitHub\DelphiSVG
set FPATH=-Fu"%BASE%\svg" -Fu"%BASE%\painter" -Fu"%BASE%\gdip" -Fu"%BASE%\lcl" -Fu"C:\lazarus\lcl\units\x86_64-win64\win32" -Fu"C:\lazarus\lcl\units\x86_64-win64" -Fu"C:\lazarus\components\lazutils\lib\x86_64-win64" -Fu"C:\lazarus\fpc\3.2.2\units\x86_64-win64"

%FPC% -Mdelphi -B -gl -Xg %FPATH% -o"%BASE%\lazarus\examples\LCLProbe.exe" "%BASE%\lazarus\examples\LCLProbe.lpr" 2>&1
echo ExitCode=%ERRORLEVEL%
if exist "%BASE%\lazarus\examples\LCLProbe.exe" (
  cd /d %BASE%\lazarus\examples
  LCLProbe.exe
)