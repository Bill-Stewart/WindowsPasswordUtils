{ Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

unit WinApi;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

interface

uses
  Windows;

type
  COMPUTER_NAME_FORMAT                    = (
    ComputerNameNetBIOS                   = 0,
    ComputerNameDnsHostname               = 1,
    ComputerNameDnsDomain                 = 2,
    ComputerNameDnsFullyQualified         = 3,
    ComputerNamePhysicalNetBIOS           = 4,
    ComputerNamePhysicalDnsHostname       = 5,
    ComputerNamePhysicalDnsDomain         = 6,
    ComputerNamePhysicalDnsFullyQualified = 7,
    ComputerNameMax                       = 8);
  EXTENDED_NAME_FORMAT   = (
    NameUnknown          = 0,
    NameFullyQualifiedDN = 1,
    NameSamCompatible    = 2,
    NameDisplay          = 3,
    NameUniqueId         = 6,
    NameCanonical        = 7,
    NameUserPrincipal    = 8,
    NameCanonicalEx      = 9,
    NameServicePrincipal = 10,
    NameDnsDomain        = 12,
    NameGivenName        = 13,
    NameSurname          = 14);

function GetExecutablePath(): string;

function GetFileVersion(const FileName: string): string;

function GetComputerName(const NameFormat: COMPUTER_NAME_FORMAT; var ComputerName: string): DWORD;

function GetUserName(const NameFormat: EXTENDED_NAME_FORMAT; var UserName: string): DWORD;

function SplitUserName(const FullUserName: string; var AuthorityName, UserName: string): DWORD;

function GetDcName(const DomainName: string; var DcName: string): DWORD;

function ChangeUserPassword(const DomainName, UserName: string; var OldPass, NewPass: string): DWORD;

function ResetUserPassword(const ServerName, UserName: string; const RequirePasswordChange: Boolean;
  var Password: string): DWORD;

procedure WriteWindowsMessage(const MessageID: DWORD);

procedure ReadConsoleString(const Hide: Boolean; var ResultStr: UnicodeString);

implementation

uses
  UtilStr;

const
  DS_RETURN_FLAT_NAME  = $80000000;
  DS_WRITABLE_REQUIRED = $00001000;
  NERR_BASE            = 2100;
  MAX_NERR             = NERR_BASE + 899;
  UF_LOCKOUT           = $10;

type
  LPCWSTR        = PChar;
  NET_API_STATUS = DWORD;

  GUID = record
    Data1: DWORD;
    Data2: Word;
    Data3: Word;
    Data4: array[0..7] of Byte;
  end;
  PGUID = ^GUID;

  DOMAIN_CONTROLLER_INFO = record
    DomainControllerName:        LPWSTR;
    DomainControllerAddress:     LPWSTR;
    DomainControllerAddressType: ULONG;
    DomainGuid:                  GUID;
    DomainName:                  LPWSTR;
    DnsForestName:               LPWSTR;
    Flags:                       ULONG;
    DcSiteName:                  LPWSTR;
    ClientSiteName:              LPWSTR;
  end;
  PDOMAIN_CONTROLLER_INFO = ^DOMAIN_CONTROLLER_INFO;

  USER_INFO_3 = record
    usri3_name:             LPWSTR;
    usri3_password:         LPWSTR;
    usri3_password_age:     DWORD;
    usri3_priv:             DWORD;
    usri3_home_dir:         LPWSTR;
    usri3_comment:          LPWSTR;
    usri3_flags:            DWORD;
    usri3_script_path:      LPWSTR;
    usri3_auth_flags:       DWORD;
    usri3_full_name:        LPWSTR;
    usri3_usr_comment:      LPWSTR;
    usri3_parms:            LPWSTR;
    usri3_workstations:     LPWSTR;
    usri3_last_logon:       DWORD;
    usri3_last_logoff:      DWORD;
    usri3_acct_expires:     DWORD;
    usri3_max_storage:      DWORD;
    usri3_units_per_week:   DWORD;
    usri3_logon_hours:      PBYTE;
    usri3_bad_pw_count:     DWORD;
    usri3_num_logons:       DWORD;
    usri3_logon_server:     LPWSTR;
    usri3_country_code:     DWORD;
    usri3_code_page:        DWORD;
    usri3_user_id:          DWORD;
    usri3_primary_group_id: DWORD;
    usri3_profile:          LPWSTR;
    usri3_home_dir_drive:   LPWSTR;
    usri3_password_expired: DWORD;
  end;
  PUSER_INFO_3 = ^USER_INFO_3;

// kernel32
function GetComputerNameExW(NameType: COMPUTER_NAME_FORMAT; lpBuffer: LPWSTR; var nSize: DWORD): BOOL;
  stdcall; external 'kernel32.dll';

// netapi32
function DsGetDcNameW(ComputerName, DomainName: LPCWSTR; DomainGuid: PGUID; SiteName: LPCWSTR;
  Flags: ULONG; var DomainControllerInfo: PDOMAIN_CONTROLLER_INFO): DWORD;
  stdcall; external 'netapi32.dll';

function NetApiBufferFree(Buffer: LPVOID): NET_API_STATUS;
  stdcall; external 'netapi32.dll';

function NetUserChangePassword(domainname, username, oldpassword, newpassword: LPCWSTR): NET_API_STATUS;
  stdcall; external 'netapi32.dll';

function NetUserGetInfo(servername, username: LPCWSTR; level: DWORD; var bufptr: Pointer): NET_API_STATUS;
  stdcall; external 'netapi32.dll';

function NetUserSetInfo(servername, username: LPCWSTR; level: DWORD; buf: Pointer; parm_err: PDWORD): NET_API_STATUS;
  stdcall; external 'netapi32.dll';

// secur32
function GetUserNameExW(NameFormat: EXTENDED_NAME_FORMAT; lpNameBuffer: LPWSTR; var nSize: LONG): Boolean;
  stdcall; external 'secur32.dll';

function GetExecutablePath(): string;
const
  MAX_CHARS = 65536;
var
  NumChars, BufSize, CharsCopied: DWORD;
  pName: PChar;
begin
  // Badly designed API that can't tell us the needed buffer size, so we
  // have to iterate...
  result := '';
  NumChars := 512;
  repeat
    BufSize := (NumChars * SizeOf(Char)) + SizeOf(Char);
    GetMem(pName, BufSize);
    CharsCopied := GetModuleFileNameW(0,  // HMODULE hModule
      pName,                              // LPWSTR  lpFilename
      NumChars);                          // DWORD   nSize
    if (CharsCopied < NumChars) and (CharsCopied <= MAX_CHARS) then
      result := string(pName)
    else
      NumChars := NumChars * 2;
    FreeMem(pName, BufSize);
  until (CharsCopied >= MAX_CHARS) or (result <> '');
end;

function IntToStr(const I: LongInt): string;
begin
  Str(I, result);
end;

function GetFileVersion(const FileName: string): string;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  VerInfoSize := GetFileVersionInfoSizeW(PChar(FileName),  // LPCWSTR lptstrFilename
    Handle);                                               // LPDWORD lpdwHandle
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PChar(FileName),  // LPCWSTR lptstrFilename
      Handle,                                // DWORD   dwHandle
      VerInfoSize,                           // DWORD   dwLen
      pBuffer) then                          // LPVOID  lpData
    begin
      if VerQueryValueW(pBuffer,  // LPCVOID pBlock
        '\',                      // LPCWSTR lpSubBlock
        pFileInfo,                // LPVOID  *lplpBuffer
        Len) then                 // PUINT   puLen
      begin
        with pFileInfo^ do
        begin
          result := IntToStr(HiWord(dwFileVersionMS)) + '.' +
            IntToStr(LoWord(dwFileVersionMS)) + '.' +
            IntToStr(HiWord(dwFileVersionLS));
        end;
      end;
    end;
    FreeMem(pBuffer, VerInfoSize);
  end;
end;

function GetComputerNameEx(const NameFormat: COMPUTER_NAME_FORMAT; var Name: string): DWORD;
var
  NumChars, BufSize: DWORD;
  pName: PChar;
begin
  NumChars := 0;
  // Fails and updates nSize with # characters needed, including null
  GetComputerNameExW(NameFormat,  // COMPUTER_NAME_FORMAT NameType
    nil,                          // LPWSTR               lpBuffer
    NumChars);                    // LPDWORD              nSize
  result := GetLastError();
  // If GetLastError() doesn't return ERROR_MORE_DATA, something else wrong
  if result <> ERROR_MORE_DATA then
    exit;
  BufSize := NumChars * SizeOf(Char);
  GetMem(pName, BufSize);
  if GetComputerNameExW(NameFormat,  // COMPUTER_NAME_FORMAT NameType
    pName,                           // LPWSTR               lpBuffer
    NumChars) then                   // LPDWORD              nSize
  begin
    Name := string(pName);
    result := 0;
  end
  else
    result := GetLastError();
  FreeMem(pName, BufSize);
end;

function GetUserNameEx(const NameFormat: EXTENDED_NAME_FORMAT; var Name: string): DWORD;
var
  NumChars, BufSize: LONG;
  pName: PChar;
begin
  NumChars := 0;
  // Fails and updates nSize with # characters needed, including null
  GetUserNameExW(NameFormat,  // EXTENDED_NAME_FORMAT NameFormat
    nil,                      // LPWSTR               lpNameBuffer
    NumChars);                // PULONG               nSize
  result := GetLastError();
  // If GetLastError() doesn't return ERROR_MORE_DATA, something else wrong
  if result <> ERROR_MORE_DATA then
    exit;
  BufSize := NumChars * SizeOf(Char);
  GetMem(pName, BufSize);
  if GetUserNameExW(NameFormat,  // EXTENDED_NAME_FORMAT NameFormat
    pName,                       // LPWSTR               lpNameBuffer
    NumChars) then               // PULONG               nSize
  begin
    Name := string(pName);
    result := 0;
  end
  else
    result := GetLastError();
  FreeMem(pName, BufSize);
end;

function GetComputerName(const NameFormat: COMPUTER_NAME_FORMAT; var ComputerName: string): DWORD;
begin
  result := GetComputerNameEx(NameFormat, ComputerName);
end;

function GetUserName(const NameFormat: EXTENDED_NAME_FORMAT; var UserName: string): DWORD;
begin
  result := GetUserNameEx(NameFormat, UserName);
end;

function GetDcName(const DomainName: string; var DcName: string): DWORD;
var
  Flags: ULONG;
  pDCInfo: PDOMAIN_CONTROLLER_INFO;
begin
  Flags := DS_RETURN_FLAT_NAME or DS_WRITABLE_REQUIRED;
  result := DsGetDcNameW(nil,  // LPCWSTR                 ComputerName
    PChar(DomainName),         // LPCWSTR                 DomainName
    nil,                       // GUID                    DomainGuid
    nil,                       // LPCTSTR                 SiteName
    Flags,                     // ULONG                   Flags
    pDCInfo);                  // PDOMAIN_CONTROLLER_INFO DomainControllerInfo
  if result = 0 then
  begin
    DcName := pDCInfo^.DomainControllerName;
    NetApiBufferFree(pDCInfo);
  end;
end;

function ChangeUserPassword(const DomainName, UserName: string; var OldPass, NewPass: string): DWORD;
begin
  result := NetUserChangePassword(PChar(DomainName),  // LPCWSTR domainname
    PChar(UserName),                                  // LPCWSTR username
    PChar(OldPass),                                   // LPCWSTR oldpassword
    PChar(NewPass));                                  // LPCWSTR newpassword
end;

function SplitUserName(const FullUserName: string; var AuthorityName, UserName: string): DWORD;
var
  StrList: TArrayOfString;
  Name: string;
begin
  result := ERROR_INVALID_PARAMETER;
  StrSplit(FullUserName, '\', StrList);
  if not ((Length(StrList) = 1) or (Length(StrList) = 2)) then
    exit;
  if Length(StrList) = 1 then
  begin
    if StrList[0] = '' then
      exit;
    result := GetUserName(NameSamCompatible, Name);
    if result <> 0 then
      exit;
    StrSplit(Name, '\', StrList);
    AuthorityName := StrList[0];
    UserName := FullUserName;
    result := 0;
  end
  else
  begin
    if (StrList[0] = '') or (StrList[1] = '') then
      exit;
    AuthorityName := StrList[0];
    UserName := StrList[1];
    result := 0;
  end;
end;

function ResetUserPassword(const ServerName, UserName: string; const RequirePasswordChange: Boolean;
  var Password: string): DWORD;
var
  pUserInfo: PUSER_INFO_3;
begin
  result := NetUserGetInfo(PChar(ServerName),  // LPCWSTR servername
    PChar(UserName),                           // LPCWSTR username
    3,                                         // DWORD   level
    pUserInfo);                                // LPBYTE  bufptr
  if result <> 0 then
    exit;
  if RequirePasswordChange then
    pUserInfo^.usri3_password_expired := 1
  else
    pUserInfo^.usri3_password_expired := 0;
  if (pUserInfo^.usri3_flags and UF_LOCKOUT) <> 0 then
    pUserInfo^.usri3_flags := pUserInfo^.usri3_flags and (not UF_LOCKOUT);
  pUserInfo^.usri3_password := PChar(Password);
  result := NetUserSetInfo(PChar(ServerName),  // LPCWSTR servername
    PChar(UserName),                           // LPCWSTR username
    3,                                         // DWORD   level
    pUserInfo,                                 // LPBYTE  buf
    nil);                                      // LPDWORD parm_err
  NetApiBufferFree(pUserInfo);
end;

procedure WriteWindowsMessage(const MessageID: DWORD);
var
  FormatFlags: DWORD;
  hModuleHandle: HMODULE;
  pBuffer: PChar;
begin
  FormatFlags := FORMAT_MESSAGE_ALLOCATE_BUFFER or
    FORMAT_MESSAGE_IGNORE_INSERTS or
    FORMAT_MESSAGE_FROM_SYSTEM;
  hModuleHandle := 0;
  if (MessageID >= NERR_BASE) and (MessageID <= MAX_NERR) then
  begin
    hModuleHandle := LoadLibraryEx('netmsg.dll',  // LPCWSTR lpLibFileName
      0,                                          // HANDLE  hFile
      LOAD_LIBRARY_AS_DATAFILE);                  // DWORD   dwFlags
    if hModuleHandle <> 0 then
      FormatFlags := FormatFlags or FORMAT_MESSAGE_FROM_HMODULE;
  end;
  if FormatMessageW(FormatFlags,                // DWORD   dwFlags
    Pointer(hModuleHandle),                     // LPCVOID lpSource
    MessageID,                                  // DWORD   dwMessageId
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),  // DWORD   dwLanguageId
    @pBuffer,                                   // LPWSTR  lpBuffer
    0,                                          // DWORD   nSize
    nil) > 0 then                               // va_list *Arguments
  begin
    if (MessageID <> 0) and (MessageID <> ERROR_CANCELLED) then
      Write('Error ', MessageID, ' - ');
    WriteLn(string(pBuffer));
    LocalFree(HLOCAL(pBuffer));  // HLOCAL hMem
  end
  else
  begin
    WriteLn('Error ', MessageID);
  end;
  if hModuleHandle <> 0 then
    FreeLibrary(hModuleHandle);  // HMODULE hLibModule
end;

procedure ReadConsoleString(const Hide: Boolean; var ResultStr: UnicodeString);
const
  MAX_CHARS = 258;  // 256 maximum chars, including CR+LF
var
  CHandle: HANDLE;
  CMode, NewCMode, CharsRead, Len: DWORD;
  pBuf: PWideChar;
begin
  CHandle := CreateFile('CONIN$',   // LPCTSTR               lpFileName
    GENERIC_READ or GENERIC_WRITE,  // DWORD                 dwDesiredAccess
    FILE_SHARE_READ,                // DWORD                 dwShareMode
    nil,                            // LPSECURITY_ATTRIBUTES lpSecurityAttributes
    OPEN_EXISTING,                  // DWORD                 dwCreationDisposition
    0,                              // DWORD                 dwFlagsAndAttributes
    0);                             // HANDLE                hTemplateFile
  GetConsoleMode(CHandle, CMode);
  NewCMode := CMode or ENABLE_LINE_INPUT;
  if Hide then
    NewCMode := NewCMode and (not ENABLE_ECHO_INPUT)
  else
    NewCMode := NewCMode or ENABLE_ECHO_INPUT;
  SetConsoleMode(CHandle, NewCMode);
  GetMem(pBuf, MAX_CHARS * SizeOf(WideChar));
  ReadConsoleW(CHandle,  // HANDLE  hConsoleInput,
    pBuf,                // LPVOID  lpBuffer
    MAX_CHARS,           // DWORD   nNumberOfCharsToRead
    CharsRead,           // LPDWORD lpNumberOfCharsRead
    nil);                // LPVOID  pInputControl
  // Subtract 2 for CR+LF
  Len := CharsRead - 2;
  SetLength(ResultStr, Len);
  if Len > 0 then
    Move(pBuf^, ResultStr[1], Len * SizeOf(WideChar));
  if (NewCMode and ENABLE_ECHO_INPUT) = 0 then
    WriteLn();
  FillChar(pBuf^, MAX_CHARS * SizeOf(WideChar), 0);
  FreeMem(pBuf, MAX_CHARS * SizeOf(WideChar));
  SetConsoleMode(CHandle, CMode);
  CloseHandle(CHandle);
end;

begin
end.
