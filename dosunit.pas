(*
        Unit related to disk access

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

        Source file   : dosunit.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

    Change Log :

        Written by KO Myung-Hun
        Term of programming : 1999.05.28

        Modified by KO Myung-Hun
        Term of programming : 1999.07.02

        Contents :
            implementation of function AbsWrite
*)
{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$DELPHI+}
{$ENDIF}
unit DOSUnit;

interface

uses
  Dos, Os2Def;

{$IFDEF FPC}
{$PACKRECORDS 1}
{$ENDIF}

type
  PDFree = ^TDFree;
  TDFree = record
    Avail : Word;
    Total : Word;
    BSec  : Word;
    SClus : Word;
  end;

  PFATInfo = ^TFATInfo;
  TFATInfo = record
    SClus : Byte;
    FATID : Byte;
    NClus : Word;
    BySec : Word;
  end;

  PFCB = ^TFCB;
  TFCB = record
    Drive    : Byte;
    Name     : array [0..7] of Char;
    Ext      : array [0..2] of Char;
    CurBlk   : Integer;
    RecSize  : Integer;
    FileSize : Longint;
    Date     : Integer;
    Time     : Integer;
    Resv     : array [0..7] of Char;
    CurRec   : Byte;
    Random   : Longint;
  end;

  PXFCB = ^TXFCB;
  TXFCB = record
    Flag : Byte;
    Resv : array [0..4] of Char;
    Attr : Byte;
    FCB  : TFCB;
  end;

  function  AbsRead(Drv : Byte; NSector, Sector : Longint;var Buffer) : Longint;
  function  AbsWrite(Drv : Byte; NSector, Sector : Longint;var Buffer) : Longint;

implementation

{$IFDEF FPC}
uses
    DosCalls;
{$ELSE}
uses
    Os2Base;
{$ENDIF}

function GetLDrv( Drv : Byte; var Handle : Longint ) : Longint;
var
    FileName    : string[ 3 ];
    ActionTaken : Longint;

begin
    FileName := 'A:'#0;
    FileName[ 1 ] := Chr( Ord( 'A' ) + drv );

{$IFDEF FPC}
    GetLDrv := DosOpen( FileName, Handle, ActionTaken, 0, 0,
                        doOpen, doDASD or doRandom or doDenyWrite or doReadWrite, nil );
{$ELSE}
    GetLDrv := DosOpen( @FileName[ 1 ], Handle, ActionTaken, 0, 0,
                        file_Open, open_flags_DASD or open_flags_Random or
                        open_share_DenyWrite or open_access_ReadWrite, nil );

{$ENDIF}
end;

function FreeLDrv( Handle : Longint ) : Longint;
begin
    FreeLDrv := DosClose( Handle );
end;

const
    IOCtlLogicalDisk    = $08;
    LockLogicalVolume   = $00;
    UnlockLogicalVolume = $01;

function LockDrv( Handle : Longint ) : Longint;
var
    CmdInfo     : Byte;
    ParamLen    : Longint;
    Data        : Byte;
    DataLen     : Longint;

begin
    CmdInfo := 0;
    ParamLen := SizeOf( Byte );

    Data := 0;
    DataLen := SizeOf( Byte );

{$IFDEF FPC}
    LockDrv :=  DosDevIOCtl( handle, IOCtlLogicalDisk, LockLogicalVolume, cmdInfo,
                             paramLen, paramLen, data, dataLen, dataLen );
{$ELSE}
    LockDrv :=  DosDevIOCtl( handle, IOCtlLogicalDisk, LockLogicalVolume, @cmdInfo,
                             paramLen, @paramLen, @data, dataLen, @dataLen );
{$ENDIF}
end;

function UnlockDrv( Handle : Longint ) : Longint;
var
    CmdInfo     : Byte;
    ParamLen    : Longint;
    Data        : Byte;
    DataLen     : Longint;

begin
    CmdInfo := 0;
    ParamLen := SizeOf( Byte );

    Data := 0;
    DataLen := SizeOf( Byte );

{$IFDEF FPC}
    UnlockDrv :=  DosDevIOCtl( handle, IOCtlLogicalDisk, UnlockLogicalVolume, cmdInfo,
                               paramLen, paramLen, data, dataLen, dataLen );
{$ELSE}
    UnlockDrv :=  DosDevIOCtl( handle, IOCtlLogicalDisk, UnlockLogicalVolume, @cmdInfo,
                               paramLen, @paramLen, @data, dataLen, @dataLen );
{$ENDIF}
end;


const
    SectorSize  = 512;
    MaxSector   = ( MaxLongint div SectorSize );

function AbsRead( Drv : Byte; NSector, Sector : Longint; var Buffer ) : Longint;
var
    Handle      : Longint;
    FPtr        : Longint;
    BufferLen   : Longint;
    I           : Integer;
    RC          : Longint;

begin
    RC := GetLDrv( Drv, Handle );
    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    RC := LockDrv( handle );
    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    for I := 1 to ( Sector div MaxSector ) do
    begin
{$IFDEF FPC}
        RC := DosSetFilePtr( Handle, MaxSector * SectorSize, dsRelative, FPtr );
{$ELSE}
        RC := DosSetFilePtr( Handle, MaxSector * SectorSize, file_Current, FPtr );
{$ENDIF}
        if RC <> 0 then
        begin
            AbsRead := RC;
            Exit;
        end;
    end;

{$IFDEF FPC}
    RC := DosSetFilePtr( Handle, ( Sector mod MaxSector ) * SectorSize, dsRelative, FPtr );
{$ELSE}
    RC := DosSetFilePtr( Handle, ( Sector mod MaxSector ) * SectorSize, file_Current, FPtr );
{$ENDIF}

    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    BufferLen := NSector * SectorSize;
    RC := DosRead( Handle, Buffer, BufferLen, BufferLen );
    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    RC := UnlockDrv( handle );
    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    RC := FreeLDrv( Handle );
    if RC <> 0 then
    begin
        AbsRead := RC;
        Exit;
    end;

    AbsRead := 0;
end;

function  AbsWrite(Drv : Byte; NSector, Sector : Longint;var Buffer) : Longint;
var
    Handle      : Longint;
    FPtr        : Longint;
    BufferLen   : Longint;
    I           : Integer;
    RC          : Longint;

begin
    RC := GetLDrv( Drv, Handle );
    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    RC := LockDrv( handle );
    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    for I := 1 to ( Sector div MaxSector ) do
    begin
{$IFDEF FPC}
        RC := DosSetFilePtr( Handle, MaxSector * SectorSize, dsRelative, FPtr );
{$ELSE}
        RC := DosSetFilePtr( Handle, MaxSector * SectorSize, file_Current, FPtr );
{$ENDIF}
        if RC <> 0 then
        begin
            AbsWrite := RC;
            Exit;
        end;
    end;

{$IFDEF FPC}
    RC := DosSetFilePtr( Handle, ( Sector mod MaxSector ) * SectorSize, dsRelative, FPtr );
{$ELSE}
    RC := DosSetFilePtr( Handle, ( Sector mod MaxSector ) * SectorSize, file_Current, FPtr );
{$ENDIF}

    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    BufferLen := NSector * SectorSize;
    RC := DosWrite( Handle, Buffer, BufferLen, BufferLen );
    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    RC := UnlockDrv( handle );
    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    RC := FreeLDrv( Handle );
    if RC <> 0 then
    begin
        AbsWrite := RC;
        Exit;
    end;

    AbsWrite := 0;
end;

end.
