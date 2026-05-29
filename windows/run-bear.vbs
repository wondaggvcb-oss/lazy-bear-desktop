' Bear / Lazy Bear Desktop Launcher
' This script starts Bear without showing a command window

Dim WshShell
Set WshShell = CreateObject("WScript.Shell")

' Get current directory
Dim currentDir
currentDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)

' Check Python
Dim pythonCmd
pythonCmd = "pythonw"

' Try to start
Dim cmd
cmd = "cmd /c cd /d """ & currentDir & """ && " & pythonCmd & " bear_app.py"

On Error Resume Next
WshShell.Run cmd, 0, False

If Err.Number <> 0 Then
    ' pythonw failed, try python
    cmd = "cmd /c cd /d """ & currentDir & """ && python bear_app.py"
    Err.Clear
    WshShell.Run cmd, 0, False
    
    If Err.Number <> 0 Then
        MsgBox "Failed to start. Please install Python 3.7+", vbCritical, "Bear"
    End If
End If

On Error GoTo 0
Set WshShell = Nothing
