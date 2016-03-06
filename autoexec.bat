SET DEBUG=1

REM ==== Base Path
SET PATH=%PATH%;c:\dos
SET UTIL=c:\util


REM ==== Mouse driver
mouse.exe

REM ==== Setup Soundblaster AWE64 paths
SET SOUND=c:\util\awe64
SET PATH=%PATH%;%SOUND%
SET CTCM=%SOUND%\CTCM 

REM ==== AWE64: Configure the card using PnP (ctcm)
SET BLASTER=A220 I5 D3 H6 P300 E640 T6
%sound%\ctcm.exe

REM ==== AWE64: MIDI setup
SET MIDI=SYNTH:1 MAP:E MODE:0 

REM ==== AWE64: Enable reverb
%sound%\AWEUTIL /S 
G
REM ==== ???
%sound%\MIXERSET /P /Q 

REM ==== AWE64: Helpful output if debug is on
IF "%debug%"=="1" ( %sound%\DIAGNOSE /S )

REM ==== ???
%sound%\AWEUTIL /S

REM ==== ???
%sound%\MIXERSET /P /Q

REM ==== AWE64: Helpful output if debug is on
IF "%debug%"=="1" ( %sound%\CTCU /S )

REM ==== Clear screen if debug is off
IF "%debug%"=="0" ( @cls )

SET DEBUG=1

REM ==== Base Path
SET PATH=%PATH%;c:\dos\bin

REM ==== Up arrow to type last command
LH doskey.exe

REM ==== Load high Mouse driver
lh mouse.exe
…

REM ==== Setup Soundblaster AWE64 paths
SET SOUND=c:\dos\awe64
SET PATH=%PATH%;%SOUND%
SET CTCM=%SOUND%\CTCM

SET BLASTER=A220 I5 D1 H5 T6 P330 E640
REM          |   |  |  |  |  |    |___ AWE 32/64 Only Parameter
REM          |   |  |  |  |  |________ MIDI Port
REM          |   |  |  |  |___________ Type of Card
REM          |   |  |  |______________ High DMA Channel
REM          |   |  |_________________ Low DMA Channel
REM          |   |____________________ Inter  rupt
REM          |________________________ Port Address

REM ==== AWE64: Setup PnP card using BLASTER var
…
