#ifndef SourceDir
  #define SourceDir "..\..\dist\windows"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist\installer"
#endif
[Setup]
AppId={{D4D04389-A32D-48D2-94E3-402440FC9731}
AppName=DentalLab
AppVersion=0.7.0
AppPublisher=DentalLab
DefaultDirName={localappdata}\Programs\DentalLab
DefaultGroupName=DentalLab
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=DentalLab-Setup-Windows-x64
SetupIconFile=..\..\Resources\DentalLab.ico
UninstallDisplayIcon={app}\DentalLab.exe
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
AppMutex=Global\DentalLab.LocalArchive
CloseApplications=no
RestartApplications=no
DisableProgramGroupPage=yes
UsePreviousAppDir=yes

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "Crea un collegamento sul desktop"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DentalLab"; Filename: "{app}\DentalLab.exe"
Name: "{autodesktop}\DentalLab"; Filename: "{app}\DentalLab.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\DentalLab.exe"; Description: "Apri DentalLab"; Flags: nowait postinstall skipifsilent

; The archive lives outside {app}. Uninstall removes only installed app files.
; Never add an UninstallDelete wildcard for LocalAppData/DentalLab.
