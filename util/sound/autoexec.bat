REM ==== Setup Soundblaster AWE paths
SET SOUND=c:\util\sound\util
SET PATH=%PATH%;%SOUND%
SET CTCM=%SOUND%\CTCM

REM ==== AWE: Configure the card using PnP (ctcm)
SET BLASTER=A220 I5 D1 H5 T6 P330 E640
REM          |   |  |  |  |  |    |___ AWE 32/64 Only Parameter
REM          |   |  |  |  |  |________ MIDI Port
REM          |   |  |  |  |___________ Type of Card
REM          |   |  |  |______________ High DMA Channel
REM          |   |  |_________________ Low DMA Channel
REM          |   |____________________ Inter  rupt
REM          |________________________ Port Address
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
