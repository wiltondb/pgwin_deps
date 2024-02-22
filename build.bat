@echo off

call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

set PATH=%PATH%;%~dp0tools\nasm-2.16.01;%~dp0tools\gperf-3.0.1\bin

perl %~dp0build.pl %*
