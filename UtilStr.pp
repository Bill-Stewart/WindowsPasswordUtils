{ Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

unit UtilStr;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

interface

type
  TArrayOfString = array of string;

procedure GetHiddenInput(const Prompt: string; var ResultStr: string;
  const Confirm: Boolean);

procedure GetHiddenInput2(const Prompt1, Prompt2: string;
  var ResultStr1, ResultStr2: string);

function Query(const Prompt: string): Boolean;

function SameText(const S1, S2: string): Boolean;

procedure StrSplit(S, Delim: string; var Dest: TArrayOfString);

function Trim(const S: string): string;

procedure WipeString(var S: string);

implementation

uses
  WinApi, Windows;

procedure GetHiddenInput(const Prompt: string; var ResultStr: string;
  const Confirm: Boolean);
var
  TestStr: string;
  Ok: Boolean;
begin
  if Confirm then
  begin
    repeat
      Write('Enter ', Prompt, ': ');
      ReadConsoleString(true, TestStr);
      Write('Confirm ', Prompt, ': ');
      ReadConsoleString(true, ResultStr);
      Ok := TestStr = ResultStr;
      if not Ok then
      begin
        WriteLn('Entries do not match');
        WipeString(ResultStr);
        WipeString(TestStr);
        WriteLn();
      end;
    until Ok;
    WipeString(TestStr);
  end
  else
  begin
    Write('Enter ', Prompt, ': ');
    ReadConsoleString(true, ResultStr);
  end;
end;

procedure GetHiddenInput2(const Prompt1, Prompt2: string;
  var ResultStr1, ResultStr2: string);
var
  TestStr: string;
  Ok: Boolean;
begin
  repeat
    Write('Enter ', Prompt1, ': ');
    ReadConsoleString(true, ResultStr1);
    Write('Enter ', Prompt2, ': ');
    ReadConsoleString(true, TestStr);
    Write('Confirm ', Prompt2, ': ');
    ReadConsoleString(true, ResultStr2);
    Ok := TestStr = ResultStr2;
    if not Ok then
    begin
      WriteLn('Entries do not match');
      WipeString(TestStr);
      WipeString(ResultStr2);
      WipeString(ResultStr1);
      WriteLn();
    end;
  until Ok;
  WipeString(TestStr);
end;

function SameText(const S1, S2: string): Boolean;
const
  CSTR_EQUAL = 2;
begin
  result := CompareStringW(GetThreadLocale(),  // LCID    Locale
    LINGUISTIC_IGNORECASE,                     // DWORD   dwCmpFlags
    PChar(S1),                                 // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PChar(S2),                                 // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

function Query(const Prompt: string): Boolean;
var
  Response: string;
  Ok: Boolean;
begin
  repeat
    Write(Prompt);
    ReadConsoleString(false, Response);
    if Length(Response) > 1 then
      Response := Copy(Response, 1, 1);
    result := SameText(Response, 'y');
    Ok := SameText(Response, 'n') or result;
  until Ok;
end;

// Returns the number of times Substring appears in S
function CountSubstring(const Substring, S: string): LongInt;
var
  P: LongInt;
begin
  result := 0;
  P := Pos(Substring, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := Pos(Substring, S, P + Length(Substring));
  end;
end;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: string; var Dest: TArrayOfString);
var
  I, P: LongInt;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, then Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit;
  end;
  SetLength(Dest, I + 1);
  for I := 0 to Length(Dest) - 1 do
  begin
    P := Pos(Delim, S);
    if P > 0 then
    begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
    end
    else
      Dest[I] := S;
  end;
end;

function Trim(const S: string): string;
var
  Len, P: LongInt;
begin
  Len := Length(S);
  while (Len > 0) and (S[Len] <= ' ') do
    Dec(Len);
  P := 1;
  while (P <= Len) and (S[P] <= ' ') do
    Inc(P);
  result := Copy(S, P, 1 + Len - P);
end;

procedure WipeString(var S: string);
begin
  if Length(S) > 0 then
  begin
    FillChar(S[1], Length(S) * SizeOf(Char), #0);
  end;
end;

begin
end.
