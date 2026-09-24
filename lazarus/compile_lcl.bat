@echo off
set FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
set BASE=D:\RecursosGitHub\DelphiSVG
set FPATH=-Fu"%BASE%\svg" -Fu"%BASE%\painter" -Fu"%BASE%\gdip" -Fu"%BASE%\lcl" -Fu"C:\lazarus\lcl\units\x86_64-win64\win32" -Fu"C:\lazarus\lcl\units\x86_64-win64" -Fu"C:\lazarus\components\lazutils\lib\x86_64-win64" -Fu"C:\lazarus\fpc\3.2.2\units\x86_64-win64"

echo === SVG.pas ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\svg\SVG.pas" 2>&1
echo === SVGImage ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\lcl\SVGImage.pas" 2>&1
echo === SVGImageList ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\lcl\SVGImageList.pas" 2>&1
echo === SVGSpeedButton ===
%FPC% -Mdelphi -dFPC %FPATH% -oNUL "%BASE%\lcl\SVGSpeedButton.pas" 2>&1
echo Done.
pause
