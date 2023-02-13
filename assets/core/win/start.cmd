cd /d "%cd%"
@REM install
winsw.exe install || winsw.exe stop
@REM start 
winsw.exe start