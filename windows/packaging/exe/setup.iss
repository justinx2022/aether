[Setup]
AppId={{DA3F45DE-00B2-4EFC-81B0-BA101DCA73E8}
AppName=Aether
AppVersion={#AppVersion}
AppPublisher=Aether
AppPublisherURL=https://github.com/justinx2022/aether
AppSupportURL=https://github.com/justinx2022/aether
AppUpdatesURL=https://github.com/justinx2022/aether
DefaultDirName={autopf}\Aether
DefaultGroupName=Aether
DisableProgramGroupPage=yes
OutputBaseFilename=Aether-Windows-{#AppArch}-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\runner\resources\app_icon.ico
#if AppArch == "x64"
  ArchitecturesAllowed=x64compatible
  ArchitecturesInstallIn64BitMode=x64compatible
#else
  ArchitecturesAllowed={#AppArch}
  ArchitecturesInstallIn64BitMode={#AppArch}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Aether"; Filename: "{app}\aether.exe"
Name: "{autodesktop}\Aether"; Filename: "{app}\aether.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\aether.exe"; Description: "{cm:LaunchProgram,Aether}"; Flags: nowait postinstall skipifsilent
