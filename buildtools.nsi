; buildtools.nsi
;
; This script is the NSIS script for the retrozilla-tools installer
;
; The resulting installer is extremely simple and provided for convenience.
;
; Based on NSIS example file example1.nsi 
;
;--------------------------------

; The name of the installer
Name "RetroZilla Build Tools"

; The file to write
OutFile "output\retrozilla-tools.exe"

; The default installation directory
InstallDir C:\retrozilla-tools

; Request application privileges for Windows Vista
RequestExecutionLevel user

;--------------------------------

; Pages

Page directory
Page instfiles

;--------------------------------

; The stuff to install
Section "" ;No components page, name is not important

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  
  ; Put file there
  File /nonfatal /a /r "src\"
  
SectionEnd ; end the section
