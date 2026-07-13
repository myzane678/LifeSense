#define AppName "LifeSense"
#define AppVersion "1.5.0"
#define AppPublisher "LifeSense"
#define AppExeName "life_sense.exe"
#define ReleaseDir "build\windows\x64\runner\Release"

[Setup]
AppId={{5C5F9B65-6B12-4AB2-9774-7D617BA2613D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=build\installer
OutputBaseFilename=LifeSense-{#AppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#AppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional options:"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 {#AppName}"; Flags: nowait postinstall skipifsilent
