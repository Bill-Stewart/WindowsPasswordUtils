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

program ResetPassword;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.RES}

uses
  Windows,
  UtilStr,
  WinApi;

const
  PROGRAM_NAME = 'ResetPassword';
  PROGRAM_COPYRIGHT = 'Copyright (C) 2023 by Bill Stewart';

var
  Status: DWORD;
  CurrentUserName, AuthorityName, UserName, ComputerName, ServerName, FullUserName, NewPass: string;
  RequirePasswordChange: Boolean;

procedure Usage();
begin
  WriteLn(PROGRAM_NAME, ' ', GetFileVersion(GetExecutablePath()), ' - ', PROGRAM_COPYRIGHT);
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('Resets the password for a user account. You must have permissions.');
end;

procedure Done();
begin
  WriteWindowsMessage(Status);
  ExitCode := LongInt(Status);
end;

begin
  if ParamStr(1) = '/?' then
  begin
    Usage();
    exit;
  end;

  ExitProc := @Done;

  Status := GetUserName(NameSamCompatible, CurrentUserName);
  if Status <> 0 then
    exit;

  Write('Enter account name for password reset [empty=quit]: ');
  ReadConsoleString(false, UserName);
  UserName := Trim(UserName);
  if UserName = '' then
  begin
    Status := ERROR_CANCELLED;
    exit;
  end;
  Status := SplitUserName(UserName, AuthorityName, UserName);
  if Status <> 0 then
    exit;

  Status := GetComputerName(ComputerNameNetBIOS, ComputerName);
  if Status <> 0 then
    exit;

  if SameText(AuthorityName, ComputerName) then
    ServerName := '\\' + ComputerName
  else
  begin
    Status := GetDcName(AuthorityName, ServerName);
    if Status = ERROR_NO_SUCH_DOMAIN then
    begin
      Status := 0;
      ServerName := '\\' + AuthorityName;
    end;
  end;

  FullUserName := AuthorityName + '\' + UserName;

  WriteLn();
  WriteLn('Account requesting password reset: ', CurrentUserName);
  WriteLn('Password reset server: ', ServerName);
  WriteLn();

  RequirePasswordChange := Query('Require password change at next logon [Y/N]? ');
  GetHiddenInput('new password for ' + FullUserName, NewPass, true);

  Status := ResetUserPassword(ServerName, UserName, RequirePasswordChange, NewPass);
  Wipestring(NewPass);
  WriteLn();
end.
