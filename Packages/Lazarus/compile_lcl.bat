@echo off
set FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
set BASE=D:\RecursosGitHub\DelphiSVG
set FPATH=-Fu"%BASE%\src\svg" -Fu"%BASE%\src\painter" -Fu"%BASE%\src\gdip" -Fu"%BASE%\Packages\Lazarus\components" -Fu"C:\lazarus\lcl\units\x86_64-win64\win32" -Fu"C:\lazarus\lcl\units\x86_64-win64" -Fu"C:\lazarus\components\lazutils\lib\x86_64-win64" -Fu"C:\lazarus\fpc\3.2.2\units\x86_64-win64"

echo === SVG.pas ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\src\svg\SVG.pas" 2>&1
echo === SVGImage ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\Packages\Lazarus\components\SVGImage.pas" 2>&1
echo === SVGImageList ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\Packages\Lazarus\components\SVGImageList.pas" 2>&1
echo === SVGSpeedButton ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\Packages\Lazarus\components\SVGSpeedButton.pas" 2>&1
echo Done.
pause
