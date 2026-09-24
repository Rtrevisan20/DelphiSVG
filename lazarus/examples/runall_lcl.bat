@echo off
cd /d %~dp0
for %%f in (..\..\examples\*.svg) do (
  LCLTest.exe "%%f"
)