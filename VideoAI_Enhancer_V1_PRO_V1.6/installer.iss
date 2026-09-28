[Setup]
AppName=VideoAI Enhancer
AppVersion=1.6.0
DefaultDirName={autopf}\VideoAI Enhancer
DefaultGroupName=VideoAI Enhancer
OutputDir=installer
OutputBaseFilename=VideoAI_Enhancer_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
PrivilegesRequired=admin
UninstallDisplayIcon={app}\VideoAI_Enhancer.exe

[Files]
Source: "VideoAI_Enhancer.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\VideoAI Enhancer"; Filename: "{app}\VideoAI_Enhancer.exe"
Name: "{group}\VideoAI Enhancer"; Filename: "{app}\VideoAI_Enhancer.exe"

[Run]
Filename: "{app}\VideoAI_Enhancer.exe"; Description: "Abrir VideoAI Enhancer"; Flags: nowait postinstall skipifsilent
