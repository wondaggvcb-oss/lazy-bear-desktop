' 熊 / Lazy Bear Desktop 启动器
' 此脚本用于无窗口启动熊

Dim WshShell
Set WshShell = CreateObject("WScript.Shell")

' 获取当前目录
Dim currentDir
currentDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)

' 检查 Python
Dim pythonCmd
pythonCmd = "pythonw"

' 尝试启动
Dim cmd
cmd = "cmd /c cd /d """ & currentDir & """ && " & pythonCmd & " bear_app.py"

On Error Resume Next
WshShell.Run cmd, 0, False

If Err.Number <> 0 Then
    ' pythonw 失败，尝试 python
    cmd = "cmd /c cd /d """ & currentDir & """ && python bear_app.py"
    WshShell.Run cmd, 0, False
    
    If Err.Number <> 0 Then
        MsgBox "启动失败，请确保已安装 Python 3.7+", vbCritical, "熊"
    End If
End If

On Error GoTo 0
Set WshShell = Nothing
