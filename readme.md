# RetroZilla Build

This is a modified edition of [MozillaBuild 1.5](https://ftp.mozilla.org/pub/mozilla/libraries/win32/) for better use with RetroZilla. 

## Major changes from MozillaBuild
* Notepad++ portable edition included and set as default editor (aliased to npp)
* Various bash environment QOL tweaks
* retrozilla-msvc6.bat added - improved launch script with terminal selection (CMD, MinTTY, rxvt)

## Supported OS
* Windows 2000 SP4
* Windows XP x86/x64
* Windows 2003 x86/x64

## 64-bit support
retrozilla-msvc6.bat must be run from a 32-bit command prompt. To start a 32-bit command prompt, you can paste the following into the run dialog: `C:\WINDOWS\SysWOW64\cmd.exe`

## Installation
An installer has been provided under releases that will install retrozilla-tools to C:\retrozilla-tools. If you wish to install manually, make sure the src subdirectory of this repository is in an easy-to-access location without any spaces in the parent directories.