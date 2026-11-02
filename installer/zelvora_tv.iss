; Installeur Windows de ZELVORA TV (Inno Setup 6)
#define AppName "ZELVORA TV"
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{6E3C2A1B-8F4D-4C7A-9B2E-5A1D7C3F9E40}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=ZELVORA
DefaultDirName={autopf}\ZELVORA TV
DefaultGroupName=ZELVORA TV
OutputDir=..\dist
OutputBaseFilename=ZELVORA-TV-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
UninstallDisplayIcon={app}\zelvora_tv.exe
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ZELVORA TV"; Filename: "{app}\zelvora_tv.exe"
Name: "{autodesktop}\ZELVORA TV"; Filename: "{app}\zelvora_tv.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zelvora_tv.exe"; Description: "{cm:LaunchProgram,ZELVORA TV}"; Flags: nowait postinstall skipifsilent
