@echo off
rem Renders every examples\*.svg through the LCL backend (TPainterLCL) into
rem lcl_renders\*.bmp using the same sizing policy as the Delphi baseline:
rem output is intended for pixel-a-pixel comparison (Phase 5.1).
cd /d %~dp0
if not exist lcl_renders mkdir lcl_renders
for %%f in (..\..\examples\*.svg) do (
  LCLTest.exe "%%f" "lcl_renders\%%~nf.bmp"
)