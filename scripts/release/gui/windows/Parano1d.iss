#ifndef MyAppVersion
  #error MyAppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef NumericVersion
  #error NumericVersion is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef OutputBaseFilename
  #error OutputBaseFilename is required
#endif
#ifndef IconFile
  #error IconFile is required
#endif
#ifndef LicenseFile
  #error LicenseFile is required
#endif
#ifndef NoticeFile
  #error NoticeFile is required
#endif

[Setup]
AppId={{8EAD67A1-91AB-497A-81A5-8A73CF4A6F31}
AppName=Lostecho
AppVersion={#MyAppVersion}
AppVerName=Lostecho {#MyAppVersion}
AppPublisher=Lostecho
AppPublisherURL=https://lostecho.org/
AppSupportURL=https://github.com/????/lostecho/issues
AppUpdatesURL=https://github.com/????/lostecho/releases
DefaultDirName={localappdata}\Programs\Lostecho
DefaultGroupName=Lostecho
DisableProgramGroupPage=yes
AllowNoIcons=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#IconFile}
LicenseFile={#LicenseFile}
UninstallDisplayIcon={app}\Lostecho.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
VersionInfoVersion={#NumericVersion}
VersionInfoCompany=Lostecho
VersionInfoDescription=Lostecho Wallet Installer
VersionInfoProductName=Lostecho
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "chinesesimplified"; MessagesFile: "{#SourcePath}\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\lostecho-gui.exe"; DestDir: "{app}"; DestName: "Lostecho.exe"; Flags: ignoreversion
Source: "{#SourceDir}\lostecho.exe"; DestDir: "{app}"; DestName: "lostecho-node.exe"; Flags: ignoreversion
Source: "{#LicenseFile}"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "{#NoticeFile}"; DestDir: "{app}"; DestName: "NOTICE.txt"; Flags: ignoreversion

[Icons]
Name: "{group}\Lostecho"; Filename: "{app}\Lostecho.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Lostecho"; Filename: "{app}\Lostecho.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Lostecho.exe"; Description: "{cm:LaunchProgram,Lostecho}"; Flags: nowait postinstall skipifsilent
