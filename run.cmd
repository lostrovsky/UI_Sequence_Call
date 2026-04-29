@echo off
REM Manual console launcher. Closes when you Ctrl-C or close the window.
REM Reads UISequenceCall.properties from this directory.
cd /d "%~dp0"
java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar
pause
