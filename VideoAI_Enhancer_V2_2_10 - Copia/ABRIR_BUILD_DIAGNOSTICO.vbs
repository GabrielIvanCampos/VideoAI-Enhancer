Option Explicit

Dim sh, fso, p, ps, cmd
Set sh = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")

p = fso.GetParentFolderName(WScript.ScriptFullName)
ps = fso.BuildPath(p, "build_windows.ps1")

If Not fso.FileExists(ps) Then
    MsgBox "Arquivo não encontrado:" & vbCrLf & ps, 16, "VideoAI Enhancer"
    WScript.Quit 2
End If

' O VBS faz a elevação uma única vez. O PowerShell não tenta elevar novamente.
cmd = "-NoProfile -ExecutionPolicy Bypass -NoExit -Command " & Chr(34) & _
      "Set-Location -LiteralPath '" & Replace(p, "'", "''") & "'; & '" & Replace(ps, "'", "''") & "'" & Chr(34)

sh.ShellExecute "powershell.exe", cmd, p, "runas", 1
