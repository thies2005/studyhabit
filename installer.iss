[Setup]
AppName=Study Habit
AppVersion=1.0.0
DefaultDirName={autopf}\Study Habit
DefaultGroupName=Study Habit
OutputDir=build
OutputBaseFilename=StudyHabit-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\studyhabit.exe

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Study Habit"; Filename: "{app}\studyhabit.exe"
Name: "{autodesktop}\Study Habit"; Filename: "{app}\studyhabit.exe"

[Run]
Filename: "{app}\studyhabit.exe"; Description: "Launch Study Habit"; Flags: nowait postinstall skipifsilent
