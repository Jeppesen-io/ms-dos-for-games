SET DEBUG=1

REM ==== Base Path
SET PATH=%PATH%;c:\dos;c:\boot
SET BOOTSCRIPTS=c:\boot
SET UTIL=c:\util

REM ==== Mouse driver
%util%\ctmouse\1.9\ctmouse.exe

REM ==== Sound drivers
%BOOTSCRIPTS%\sound.bat awe

