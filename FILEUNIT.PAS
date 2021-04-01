(*
        Unit releated to file

        Copyright (C) 1999 by KO Myung-Hun

        This unit is free software; you can redistribute it and/or
        modify it under the terms of the GNU Library General Public
        License as published by the Free Software Foundation; either
        version 2 of the License, or any later version.

        This unit is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
        Library General Public License for more details.

        You should have received a copy of the GNU Library General Public
        License along with this library; if not, write to the Free
        Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

    Environment :

        Source file   : fileunit.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

    Change Log :

        Written by KO Myung-Hun
        Term of programming : 1999.05.28, 1999.07.11

        Modified by KO Myung-Hun
        Term of programming : 1999.11.22

        Contents :
            isShortName() check more strictly if name is short type.
*)

{$X+,V-}
{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$DELPHI+}
{$ENDIF}
unit FileUnit;

interface

uses
    Dos, FATUnit,
{$IFDEF FPC}
    DosCalls;
{$ELSE}
    Os2Base;
{$ENDIF}

type
  PFCBName = ^TFCBName;
  TFCBName = record
    Name : array [0..7] of Char;
    Ext  : array [0..2] of Char;
  end;

{$IFDEF VirtualPascal}
type
    TFileFindBuf3 = FileFindBuf3;
{$ENDIF}

  procedure Han2FCB(Han : string; var FCB);
  function  FCB2Han(var FCB) : string;
  function  InSpec(Name, Spec : string) : Boolean;
  function  IsDir( Dir : string ) : Boolean;
  function  fileExist( path : string ) : Boolean;
  function  IsWild( Path : string ) : Boolean;
  function  GetFileEA( Name : string; var FEA : TFileFindBuf3 ) : Longint;
  function  FNMerge( Dir, Name : string ) : string;
  function  GetDirCom( const Path : string ) : string;
  function  GetNameCom( const Path : string ) : string;
  function  RmLastBS( Dir : string ) : string;
  function  getShortPath( const path : string ) : string;
  function  getShortName( var ff : TVFATFindFile; const name : string ) : string;
  function  isShortName( const name : string ) : Boolean;

implementation

uses
    KUtils;

procedure Han2FCB(Han : string; var FCB);
var
  FCBName  : TFCBName absolute FCB;
  D        : DirStr;
  N        : NameStr;
  E        : ExtStr;
  Position : Byte;
  I        : Integer;

begin
  FSplit(Han, D, N, E);
  if E[1] = '.' then Delete(E, 1, 1);

  while Length(N) < 8 do N := N + ' ';

  while Length(E) < 3 do E := E + ' ';

  Position := Pos('*', N);
  if Position > 0 then
    for I := Position to 8 do N[I] := '?';

  Position := Pos('*', E);
  if Position > 0 then
    for I := Position to 3 do E[I] := '?';

  Move(N[1], FCBName.Name, 8);
  Move(E[1], FCBName.Ext, 3);
end;

function FCB2Han(var FCB) : string;
var
  FCBName  : TFCBName absolute FCB;
  Name     : string[ 8 ];
  Ext      : string[ 3 ];
  Han      : string;
  Position : Byte;

begin
  Name[ 0 ] := #8;
  Ext[ 0 ] := #3;
  Move(FCBName.Name, Name[ 1 ], 8);
  Move(FCBName.Ext, Ext[ 1 ], 3);

  Position := 8;
  while (Position > 0) and (Name[Position] = ' ') do
  begin
    Delete(Name, Position, 1);
    Dec(Position);
  end;

  Position := 3;
  while (Position > 0) and (Ext[Position] = ' ') do
  begin
    Delete(Ext, Position, 1);
    Dec(Position);
  end;

  Han := Name;
  if Length( Ext ) > 0 then
    Han := Han + '.' + Ext;

  FCB2Han := Han;
end;

function InSpec(Name, Spec : string) : Boolean;
var
  I1, I2, J1, J2 : Integer;

begin
    if ( Name = '' ) or ( Spec = '' ) then
    begin
        InSpec := False;
        Exit;
    end;

    if Name = '..' then
        Dec( Name[ 0 ]);
    if ( Length( Name ) > 0 ) and ( Pos( '.', Name ) = 0 ) then
        Name := Name + '.';

    if ( Length( Spec ) > 0 ) and ( Pos( '.', Spec ) = 0 ) and
       ( Pos( '*', Spec ) = 0 ) then
        Spec := Spec + '.';

    I1 := Pos( '*?', Spec );
    while I1 > 0 do
    begin
        Delete( Spec, I1 + 1, 1 );
        I1 := Pos( '*?', Spec );
    end;

    I1 := Pos( '**', Spec );
    while I1 > 0 do
    begin
        Delete( Spec, I1 + 1, 1 );
        I1 := Pos( '**', Spec );
    end;


    J1 := 1;
    for I1 := 1 to Length(Name) do
    begin
        if J1 > Length(Spec) then
        begin
            for J1 := I1 to Length( Name ) do
            begin
                if Name[ J1 ] <> '.' then
                begin
                    InSpec := False;
                    Exit;
                end;
            end;

            InSpec := True;
            Exit;
        end;

        if (Name[I1] = Spec[J1]) or (Spec[J1] in ['?', '*']) then
        begin
            if Spec[J1] <> '*' then
                Inc(J1)
            else
            begin
                if J1 < Length(Spec) then
                begin
                    I2 := I1;
                    J2 := J1 + 1;
                    while (I2 <= Length(Name)) and (J2 <= Length(Spec)) and
                          (not (Spec[J2] in ['?', '*'])) and
                          (Name[I2] = Spec[J2]) do
                    begin
                        Inc(I2);
                        Inc(J2);
                    end;

                    if ((J2 > Length(Spec)) and
                        ( Copy( Spec, J1 + 1, J2 - J1 - 1 ) <>
                          Copy( Name, I1 + 1, J2 - J1 - 1 ))) or
                       ((J2 <= Length(Spec)) and (Spec[J2] in ['?', '*'])) then
                    begin
                        I1 := I2 - 1;
                        J1 := J2;
                    end;
                end;
            end;
        end
        else
        begin
            InSpec := False;
            Exit;
        end;
    end;

    for I1 := J1 to Length(Spec) do
    begin
        if not (Spec[I1] in ['?', '*']) then
        begin
            InSpec := False;
            Exit;
        end;
    end;

    InSpec := True;
end;

function IsDir( Dir : string ) : Boolean;
var
    DirHandle   : Longint;
    Attr        : Longint;
    FindBuf     : TFileFindBuf3;
    Count       : Longint;
    RC          : Longint;

begin
    if IsWild( Dir ) or ( Dir = '' ) then
    begin
        IsDir := False;
        Exit;
    end;

    Dir := RmLastBS( FExpand( Dir ));
    if Length( Dir ) = 3 then
    begin
        IsDir := True;
        Exit;
    end;

    DirHandle := -1;
    Attr := $1000 or Directory;
    Count := 1;
{$IFDEF FPC}
    RC := DosFindFirst( Dir, DirHandle, Attr, @FindBuf, SizeOf( TFileFindBuf3 ),
                        Count, ilStandard );
{$ELSE}
    Dir := Dir + #0;
    RC := DosFindFirst( @Dir[ 1 ], DirHandle, Attr, FindBuf, SizeOf( TFileFindBuf3 ),
                        Count, fil_Standard );
{$ENDIF}

    DosFindClose( DirHandle );

    IsDir := ( RC = 0 ) and ( Count > 0 );
end;

function  fileExist( path : string ) : Boolean;
var
    DirHandle   : Longint;
    Attr        : Longint;
    FindBuf     : TFileFindBuf3;
    Count       : Longint;
    RC          : Longint;

begin
    if IsWild( path ) or ( path = '' ) then
    begin
        FileExist := False;
        Exit;
    end;

    path := RmLastBS( FExpand( path ));
    DirHandle := -1;
    Attr := AnyFile and not VolumeID;
    Count := 1;
{$IFDEF FPC}
    RC := DosFindFirst( path, DirHandle, Attr, @FindBuf, SizeOf( TFileFindBuf3 ),
                        Count, ilStandard );
{$ELSE}
    path := path + #0;
    RC := DosFindFirst( @path[ 1 ], DirHandle, Attr, FindBuf, SizeOf( TFileFindBuf3 ),
                        Count, fil_Standard );
{$ENDIF}

    DosFindClose( DirHandle );

    FileExist := ( RC = 0 ) and ( Count > 0 );
end;

function  IsWild( Path : string ) : Boolean;
begin
    IsWild := ( Pos( '*', path ) > 0 ) or ( Pos( '?', Path ) > 0 );
end;

function  GetFileEA( Name : string; var FEA : TFileFindBuf3 ) : Longint;
var
    Handle  : Longint;
    Action  : Longint;
    RC      : Longint;

begin
    Name := RmLastBS( Name );

{$IFDEF FPC}
    RC := DosOpen( Name, Handle, Action, 0, 0, doOpen,
                   doRandom or doRead or doDenyWrite, nil );
{$ELSE}
    Name := Name + #0;
    RC := DosOpen( @Name[ 1 ], Handle, Action, 0, 0, file_Open,
                   open_flags_Random or open_access_ReadOnly or open_share_DenyWrite, nil );
{$ENDIF}
    if RC <> 0 then
    begin
        GetFileEA := RC;
        Exit;
    end;

{$IFDEF FPC}
    RC := DosQueryFileInfo( Handle, ilStandard, @FEA, SizeOf( TFileFindBuf3 ));
{$ELSE}
    RC := DosQueryFileInfo( Handle, fil_Standard, FEA, SizeOf( TFileFindBuf3 ));
{$ENDIF}
    if RC <> 0 then
    begin
        GetFileEA := RC;
        Exit;
    end;

    RC := DosClose( Handle );
    if RC <> 0 then
    begin
        GetFileEA := RC;
        Exit;
    end;

    GetFileEA := 0;
end;

function  FNMerge( Dir, Name : string ) : string;
begin
    if ( not ( Dir[ Length( Dir )] in [ '\', ':'])) and
       ( Length( dir ) > 0 ) then
        Dir := Dir + '\';

    FNMerge := Dir + Name;
end;

function GetDirCom( const Path : string ) : string;
var
    I : Integer;

begin
    I := PosR( '\', Path );
    if I = 0 then
        I := PosR( ':', Path );

    GetDirCom := RmLastBS( Copy( Path, 1, I));
end;

function GetNameCom( const Path : string ) : string;
var
    I : Integer;

begin
    I := PosR( '\', Path );
    if I = 0 then
        I := PosR( ':', Path );

    GetNameCom := Copy( Path, I + 1, Length( Path ) - I );
end;

function  RmLastBS( Dir : string ) : string;
begin
    while ( Length( Dir ) > 1 ) and ( Dir[ Length( Dir )] = '\' ) do
    begin
        if ( Length( Dir ) = 3 ) and ( Dir[ 2 ] = ':' ) then
            break;

        Dec( Dir[ 0 ]);
    end;

    RmLastBS := Dir;
end;

function getShortPath( const path : string ) : string;
var
    ff  : PVFATFindFile;

begin
    getShortPath := '';

    if isWild( path ) or ( path = '' ) then
        Exit;

    ff := New( PVFATFindFile, Init( path, AnyFile ));
    if ff = nil then
        Exit;

    ff^.findFirst;
    if ( ff^.findError = fefNoError ) and
       ( not isWild( ff^.name^ )) then
        getShortPath := fnMerge( ff^.shortDir^, ff^.FoundEntry^.VFATFileEntry.shortName )
    else if ff^.name = nil then
        getShortPath := ff^.shortDir^
    else
        getShortPath := fnMerge( ff^.shortDir^,
                                 VFATCreateShortName( ff^.shortDir^,
                                    getNameCom( path )));
    Dispose( ff, Done );
end;

function getShortName( var ff : TVFATFindFile; const name : string ) : string;
begin
    getShortName := '';

    if isWild( name ) or ( name = '' ) then
        Exit;

    ff.setName( name );
    ff.findFirst;
    if ff.findError = fefNoError then
        getShortName := ff.foundEntry^.vfatFileEntry.shortName;
end;

function isShortName( const name : string ) : Boolean;
var
    len         : Integer;
    position    : Integer;

begin
    if isWild( name ) or ( name = '' ) or ( Pos( ' ', name ) > 0 ) then
    begin
        isShortName := False;
        Exit;
    end;

    len := Length( name );
    position := Pos( '.', name );
    if position = 0 then
    begin
        Inc( len );
        position := len;
    end;

    isShortName :=  ( position <= 9 ) and ( len - position <= 3 );
end;

end.
