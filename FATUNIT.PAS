(*
        Unit related to FAT

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

        Source file   : fatunit.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

    Change Log :

        Written by KO Myung-Hun
        Term of programming : 1999.05.28, 1999.06.20 - 1999.07.14

        Modified by KO Myung-Hun
        Term of programming : 1999.11.22

        Contents :
            bug fix :
                VFATCreateShortName() do not process last spaces.
*)
{$X+,V-}
{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$DELPHI+}
{$ENDIF}
unit FATUnit;

interface

uses
  Objects, Dos;

{$IFDEF FPC}
{$PACKRECORDS 1}
{$ENDIF}
type
  PBootSec = ^TBootSec;
  TBootSec = record
    Jump          : array [0..2] of Char;
    OEM           : array [0..7] of Char;
    BPS           : Word;
    SPC           : Byte;
    ReservedSec   : Word;
    FATs          : Byte;
    Root          : Word;
    VolSec        : Word;
    DiskType      : Byte;
    FATSec        : Word;
    SPT           : Word;
    Heads         : Word;
    HiddenSec     : Longint;
    TotalSec      : Longint;
    PhysicalDRV   : Word;
    EXTBoot       : Byte;
    VOLSerial     : Longint;
    Volume        : array [0..10] of Char;
    FileSysID     : array [0..7] of Char;
    BootStrap     : array [0..449] of Char;
  end;

  PDiskLoc = ^TDiskLoc;
  TDiskLoc = record
    FAT1st : Word;
    FAT2nd : Word;
    Root   : Word;
    Data   : Word;
  end;

const
  refNoError    = 0;
  refDiskLoc    = 1;
  refRead       = 2;
  refWrite      = 3;

type
  PFATType = ^TFATType;
  TFATType = (FAT12, FAT16);

const
  UnusedCluster = 0;

type
  PBootInfo = ^TBootInfo;
  TBootInfo = record
    TotalSectors   : Longint;
    TotalCylinders : Longint;
    TotalClusters  : Word;

    Boot           : TBootSec;
    DiskLoc        : TDiskLoc;
  end;

  PFAT = ^TFAT;
  TFAT = object
    Stop         : Boolean;
    RunError     : Integer;

    Drive        : Byte;
    BootInfo     : PBootInfo;
    FATType      : TFATType;
    LDosCluster  : Word;
    GDosCluster  : Word;
    BadCluster   : Word;
    LLastCluster : Word;
    GLastCluster : Word;

    constructor Init(Drv : Byte);
    destructor  Done; virtual;
    procedure   SetDrive(Drv : Byte); virtual;
    function    NextFAT(FATIndex, Cluster : Word) : Word; virtual;
    function    LinkFAT(FATIndex, Cluster, Next : Word) : Boolean; virtual;

(*  added by KO Myung-Hun on 1999.06.30  *)
(* ------------------------------------- *)
    function    LinkAll( cluster, next : Word ) : Boolean;
    function    nextSec( fatIndex : word; sector : Longint ) : Longint;
    function    findFreeFAT( fatIndex, cluster : Word ) : Word;
    function    clus2Sec( cluster : Word ) : Longint;
    function    sec2clus( sector : Longint ) : Word;
(* ------------------------------------- *)

  private
    function    NextFAT12(FATIndex, Cluster : Word) : Word;
    function    NextFAT16(FATIndex, Cluster : Word) : Word;
    function    LinkFAT12(FATIndex, Cluster, Next : Word) : Boolean;
    function    LinkFAT16(FATIndex, Cluster, Next : Word) : Boolean;
    procedure   SetUp;
  end;

  PFileEntry = ^TFileEntry;
  TFileEntry = record
    Name     : array [0..7] of Char;
    Ext      : array [0..2] of Char;
    Attr     : Byte;
    Unused   : array [0..9] of Byte;
    Time     : Word;
    Date     : Word;
    Cluster  : Word;
    Size     : Longint;
  end;

const
  MaxFileEntry = (512 div SizeOf(TFileEntry));

type
  PFoundEntry = ^TFoundEntry;
  TFoundEntry = record
    FileEntry    : TFileEntry;
    Sector       : Longint;
    Index        : Integer;
  end;

  PDataSec = ^TDataSec;
  TDataSec = array [0..MaxFileEntry - 1 ] of TFileEntry;

  PFileListCollection = ^TFileListCollection;
  TFileListCollection = object(TCollection)
    procedure FreeItem(Item : Pointer); virtual;
  end;

const
  fefNoError  = 0;
  fefNotFound = 1;
  fefNoMore   = 2;

type
  PFindType = ^TFindType;
  TFindType = (FirstFind, NextFind);

  PFindEntry = ^TFindEntry;
  TFindEntry = object(TFAT)
    Dir        : PString;
    FileEntry  : PFileEntry;
    FoundEntry : PFoundEntry;
    StartSec   : Longint;
    FindError  : Integer;

    constructor Init(ADir : string; var AFileEntry : TFileEntry);
    destructor  Done; virtual;
    procedure   SetDrive(Drv : Byte); virtual;
    procedure   SetDir(ADir : string); virtual;
    procedure   SetFileEntry(var AFileEntry : TFileEntry); virtual;
    procedure   FindFirst; virtual;
    procedure   FindNext; virtual;
    function    Compare(var E1, E2 : TFileEntry) : Boolean; virtual;

  private
    List         : PCollection;
    ListIndex    : Integer;
    DataSec      : PDataSec;
    Initializing : Boolean;

    procedure   ClearFoundEntry;
    procedure   ClearList;
    procedure   Find(FindType : TFindType);
    procedure   Setup;
  end;

  PFindFile = ^TFindFile;
  TFindFile = object(TFindEntry)
    Path : PString;
    Name : PString;

    constructor Init(APath : string; Attrib : Byte);
    destructor  Done; virtual;
    procedure   SetDir(ADir : string); virtual;
    procedure   SetPath(APath : string); virtual;
    (* added by KO Myung-Hun on 1999.07.02 *)
    procedure   SetName(AName : string); virtual;
    procedure   SetAttr(Attrib : Byte); virtual;
    function    Compare(var E1, E2 : TFileEntry) : Boolean; virtual;
  end;

const
    AttrOfLongFile = ReadOnly or Hidden or SysFile or VolumeID;

type
    PShortName = ^TShortName;
    TShortName = string[ 12 ];

    PLongName  = ^TLongName;
    TLongName  = string;

    PVFATFileEntry = ^TVFATFileEntry;
    TVFATFileEntry = record
        LongName  : TLongName;
        ShortName : TShortName;
        CheckSum  : Byte;
        FileEntry : TFileEntry;
    end;

    PVFATFoundEntry = ^TVFATFoundEntry;
    TVFATFoundEntry = record
        VFATFileEntry : TVFATFileEntry;
        Sector        : Longint;
        Index         : Integer;
        Slots         : Integer;
    end;

    (* from include\linux\msdos_fs.h *)
    (* Up to 13 characters of the name *)
    PVFATSlot = ^TVFATSlot;
    TVFATSlot = record
        id          : Byte;                     (* sequence number for slot *)
        name0_4     : array[ 0..9 ] of Char;    (* first 5 characters in name *)
        attr        : Byte;                     (* attribute byte *)
        reserved    : Byte;                     (* always 0 *)
        checkSum    : Byte;                     (* checksum for 8.3 alias *)
        name5_10    : array[ 0..11 ] of Char;   (* 6 more characters in name *)
        start       : Word;                     (* starting cluster number *)
        name11_12   : array[ 0..3 ] of Char;    (* last 2 characters in name *)
    end;

    PVFATFindFile = ^TVFATFindFile;
    TVFATFindFile = object
        FileEntry  : PVFATFileEntry;
        FoundEntry : PVFATFoundEntry;
        Path       : PString;
        dir        : PString;
        ShortDir   : PString;
        name       : PString;
        StartSec   : Longint;
        fat        : PFAT;

        RunError   : Integer;
        FindError  : Integer;

        constructor Init( APath : string; Attrib : Byte );
        destructor  Done; virtual;
        procedure   SetPath( APath : string ); virtual;
        (* added by KO Myung-Hun on 1999.07.04 *)
        procedure   setDir( aDir : string ); virtual;
        procedure   setName( aName : string ); virtual;
        procedure   SetAttr( Attrib : Byte ); virtual;
        procedure   FindFirst; virtual;
        procedure   FindNext; virtual;
        function    Compare( var E1, E2 : TVFATFileEntry ) : Boolean; virtual;
        function    CheckSumOk : Boolean; virtual;
        function    GetName : string;

    private
        FF       : PFindFile;

        function  GetLongName : TLongName;
        function  GetShortName : TShortName;
        procedure Find( FindType : TFindType );
        procedure Setup;
    end;

    function GetBootInfo(Drive : Byte; var ABootInfo : TBootInfo) : Boolean;
    function IsFAT( Drive : Byte ) : Boolean;
    function asc2uni( const s : string ) : string;
    function uni2asc( const s : string ) : string;
    function VFATValidLongName( const LongName : string ) : Boolean;
    function VFATCreateShortName( const dir, name : string ) : string;
    function VFATCreateFile( var ff : TFindFile; const name : string; var fe : TFileEntry ) : Boolean;
    function eraseLongSlot( const path : string ) : Boolean;
    function fat2VFAT( var ff : TFindFile; const shortName, longName : string ) : Boolean;

implementation

uses
    DosUnit, FileUnit, KUtils;

function GetBootInfo(Drive : Byte; var ABootInfo : TBootInfo) : Boolean;
var
  BootSec : TBootSec;

procedure GetDiskLoc;
begin
  with ABootInfo.DiskLoc do
  begin
    FAT1st := BootSec.ReservedSec;
    FAT2nd := FAT1st;
    if BootSec.FATs > 1 then Inc(FAT2nd, BootSec.FATSec);

    Root := FAT1st + (BootSec.FATSec * BootSec.FATs);
    Data := Root + (BootSec.Root shr 4);
  end;
end;

begin (* GetBootInfo *)
  GetBootInfo := False;

  if AbsRead(Drive, 1, 0, BootSec) <> 0 then Exit;

  GetDiskLoc;

  with ABootInfo do
  begin
    if BootSec.VolSec <> 0 then TotalSectors := BootSec.VolSec
    else TotalSectors := BootSec.TotalSec;

    TotalCylinders := TotalSectors div BootSec.SPT;
    TotalClusters  := TotalSectors div BootSec.SPC;
  end;

  Move(BootSec, ABootInfo.Boot, SizeOf(TBootSec));

  GetBootInfo := True;
end;

function IsFAT( Drive : Byte ) : Boolean;
var
    BootSec : TBootSec;

begin
    IsFAT := False;

    if AbsRead( Drive, 1, 0, BootSec ) <> 0 then
        Exit;

    if ( BootSec.FileSysID[ 0 ] = 'F' ) and
       ( BootSec.FileSysID[ 1 ] = 'A' ) and
       ( BootSec.FileSysID[ 2 ] = 'T' ) then
        IsFAT := True;
end;

constructor TFAT.Init(Drv : Byte);
begin
  New(BootInfo);
  if BootInfo = nil then Fail;

  if not GetBootInfo(Drv, BootInfo^) then Fail;

  Drive := Drv;

  SetUp;
end;

destructor TFAT.Done;
begin
  if BootInfo <> nil then Dispose(BootInfo);
end;

procedure TFAT.SetDrive(Drv : Byte);
begin
  if Drive = Drv then
    Exit;

  if not GetBootInfo(Drv, BootInfo^) then Exit;

  Drive := Drv;

  SetUp;
end;

function TFAT.NextFAT(FATIndex, Cluster : Word) : Word;
begin
  if Stop then
  begin
    NextFAT := GLastCluster;
    Exit;
  end;

  if FATType = FAT12 then NextFAT := NextFAT12(FATIndex, Cluster)
  else NextFAT := NextFAT16(FATIndex, Cluster);
end;

function TFAT.NextFAT12(FATIndex, Cluster : Word) : Word;
var
  Sector : Longint;
  Offset : Word;
  Buffer : array[0..1023] of Byte;

begin
  NextFAT12 := GLastCluster;

  Sector := FATIndex + ((Cluster + (Cluster shr 1)) div BootInfo^.Boot.BPS);
  Offset := (Cluster + (Cluster shr 1)) mod BootInfo^.Boot.BPS;

  if AbsRead(Drive, 2, Sector, Buffer) <> 0 then Exit;

  Result := Buffer[Offset];

  Inc(Offset);
  Result := Result or (Buffer[Offset] shl 8);

  if Odd(Cluster) then Result := Result shr 4
  else Result := Result and $FFF;
end;

function TFAT.NextFAT16(FATIndex, Cluster : Word) : Word;
var
  Sector : Longint;
  Offset : Word;
  Buffer : array[0..1023] of Byte;

begin
  NextFAT16 := GLastCluster;

  Sector := FATIndex + ((Longint(Cluster) shl 1) div BootInfo^.Boot.BPS);
  Offset := (Longint(Cluster) shl 1) mod BootInfo^.Boot.BPS;

  if AbsRead(Drive, 2, Sector, Buffer) <> 0 then Exit;

  NextFAT16 := Buffer[Offset] or (Buffer[Offset + 1] shl 8);
end;

function TFAT.LinkFAT(FATIndex, Cluster, Next : Word) : Boolean;
begin
  if Stop then
  begin
    LinkFAT := False;
    Exit;
  end;

  if FATType = FAT12 then LinkFAT := LinkFAT12(FATIndex, Cluster, Next)
  else LinkFAT := LinkFAT16(FATIndex, Cluster, Next);
end;

function TFAT.linkAll( cluster, next : Word ) : Boolean;
var
    fatIndex : Word;
    i        : Integer;

begin
    LinkAll := False;

    fatIndex := bootInfo^.diskLoc.fat1st;

    for i := 1 to bootInfo^.boot.fats do
    begin
        if not linkFAT( fatIndex, cluster, next ) then
            Exit;

        Inc( fatIndex, bootInfo^.boot.fatSec );
    end;

    linkAll := True;
end;

function TFAT.LinkFAT12(FATIndex, Cluster, Next : Word) : Boolean;
var
  Sector : Longint;
  Offset : Word;
  Buffer : array [0..1023] of Byte;

begin
  LinkFAT12 := False;

  Sector := FATIndex + ((Cluster + (Cluster shr 1)) div BootInfo^.Boot.BPS);
  Offset := (Cluster + (Cluster shr 1)) mod BootInfo^.Boot.BPS;

  if AbsRead(Drive, 2, Sector, Buffer) <> 0 then Exit;

  if Odd(Cluster) then
    Buffer[Offset] := (Buffer[Offset] and $0F) or ((Next and $0F) shl 4)
  else Buffer[Offset] := Lo(Next);

  Inc(Offset);
  if Odd(Cluster) then Buffer[Offset] := (Next and $FF0) shr 4
  else
    Buffer[Offset] := (Buffer[Offset] and $F0) or (Hi(Next) and $0F);

  if AbsWrite(Drive, 2, Sector, Buffer) <> 0 then Exit;

  LinkFAT12 := True;
end;

function TFAT.LinkFAT16(FATIndex, Cluster, Next : Word) : Boolean;
var
  Sector : Longint;
  Offset : Word;
  Buffer : array [0..1023] of Byte;

begin
  LinkFAT16 := False;

  Sector := FATIndex + ((Longint(Cluster) shl 1) div BootInfo^.Boot.BPS);
  Offset := (Longint(Cluster) shl 1) mod BootInfo^.Boot.BPS;

  if AbsRead(Drive, 2, Sector, Buffer) <> 0 then Exit;

  Buffer[Offset] := Lo(Next);
  Buffer[Offset + 1] := Hi(Next);

  if AbsWrite(Drive, 2, Sector, Buffer) <> 0 then Exit;

  LinkFAT16 := True;
end;

(*  added by KO Myung-Hun on 1999.06.30 *)
function TFAT.nextSec( fatIndex : Word; sector : Longint ) : Longint;
var
    c : Word;

begin
    nextSec := -1;

    c := sec2clus( sector );
    Inc( sector );
    if sector = bootInfo^.diskLoc.data then
        exit;

    if ( sector > bootInfo^.diskLoc.data ) and
       ( sector >= ( clus2sec( c ) + bootInfo^.boot.spc )) then
    begin
        c := nextFAT( fatIndex, c );
        if c >= LLastCluster then
            exit;

        sector := clus2sec( c );
    end;

    nextSec := sector;
end;

function TFAT.findFreeFAT( fatIndex, cluster : Word ) : Word;
var
    freeCluster : Word;

begin
    findFreeFAT := 0;

    if nextFAT( fatIndex, cluster ) = UnusedCluster then
    begin
        findFreeFAT := cluster;
        Exit;
    end;

    freeCluster := cluster + 1;
    while ( nextFAT( fatIndex, freeCluster ) <> UnusedCluster ) and
          ( freeCluster <> cluster ) do
    begin
        Inc( freeCluster );

        if freeCluster > bootInfo^.totalClusters then
            freeCluster := 2;
    end;

    if freeCluster <> cluster then
        findFreeFAT := freeCluster;
end;

function TFAT.clus2Sec( cluster : Word ) : Longint;
begin
    clus2Sec := bootInfo^.diskLoc.data + Longint( cluster - 2) *
      bootInfo^.boot.spc;
end;

function TFAT.sec2clus( sector : Longint ) : Word;
begin
    sec2clus := ((sector - BootInfo^.DiskLoc.Data) div BootInfo^.Boot.SPC) + 2;
end;

procedure TFAT.SetUp;
begin
  Stop := False;
  RunError := refNoError;

  if BootInfo^.TotalClusters < $FF7 then
  begin
    FATType := FAT12;
    LDosCluster  := $FF0;
    GDosCluster  := $FF6;
    BadCluster   := $FF7;
    LLastCluster := $FF8;
    GLastCluster := $FFF;
  end
  else
  begin
    FATType := FAT16;
    LDosCluster  := $FFF0;
    GDosCluster  := $FFF6;
    BadCluster   := $FFF7;
    LLastCluster := $FFF8;
    GLastCluster := $FFFF;
  end;
end;

procedure TFileListCollection.FreeItem(Item : Pointer);
begin
  if Item <> nil then Dispose(PFoundEntry(Item));
end;

constructor TFindEntry.Init(ADir : string; var AFileEntry : TFileEntry);
var
  Expand : string;

begin
  Expand := FExpand(ADir);
  if not TFAT.Init(Ord(Expand[1]) - Ord('A')) then
    Fail;

  while (Length(Expand) > 0) and (Expand[Length(Expand)] = '\') do
    Dec(Expand[0]);
  Expand := Expand + '\';

  Dir := NewStr(Expand);
  New(FileEntry);
  New(FoundEntry);
  New(DataSec);
  List := New(PFileListCollection, Init(10, 5));
  if (Dir = nil) or (FileEntry = nil) or (FoundEntry = nil) or
     (DataSec = nil) or (List = nil) then
    Fail;

  Move(AFileEntry, FileEntry^, SizeOf(TFileEntry));

  Setup;
end;

destructor TFindEntry.Done;
begin
  TFAT.Done;

  if Dir <> nil then DisposeStr(Dir);
  if FileEntry <> nil then Dispose(FileEntry);
  if FoundEntry <> nil then Dispose(FoundEntry);
  if DataSec <> nil then Dispose(DataSec);
  if List <> nil then Dispose(List, Done);
end;

procedure TFindEntry.SetDrive(Drv : Byte);
var
  ADir : string;

begin
  if Stop or (Drive = Drv) then Exit;

  ADir := Dir^;
  ADir[1] := Chr(Ord('A') + Drv);

  SetDir(ADir);
end;

procedure TFindEntry.SetDir(ADir : string);
var
  Expand : string;

begin
  if Stop then Exit;

  if Dir <> nil then DisposeStr(Dir);

  Expand := FExpand(ADir);
  TFAT.SetDrive(Ord(Expand[1]) - Ord('A'));

  while (Length(Expand) > 2) and (Expand[Length(Expand)] = '\') do
    Dec(Expand[0]);
  Expand := Expand + '\';

  Dir := NewStr(Expand);

  Setup;
end;

procedure TFindEntry.SetFileEntry(var AFileEntry : TFileEntry);
begin
  if Stop then Exit;

  Move(AFileEntry, FileEntry^, SizeOf(TFileEntry));
  ClearFoundEntry;
end;

procedure TFindEntry.ClearList;
begin
  if List = nil then Exit;

  List^.FreeAll;
end;

procedure TFindEntry.ClearFoundEntry;
begin
  FillChar(FoundEntry^, SizeOf(TFoundEntry), ' ');
end;

procedure TFindEntry.FindFirst;
begin
  if Stop then Exit;

  Find(FirstFind);
end;

procedure TFindEntry.FindNext;
begin
  if Stop then Exit;

  Find(NextFind);
end;

function TFindEntry.Compare(var E1, E2 : TFileEntry) : Boolean;
begin
  Compare := MemCmp(E1, E2, SizeOf(TFileEntry)) = 0;
end;

(*
    fixed by KO Myung-Hun on 1999.07.08

    contents : if last entry does not include #0 entry,
               procedure Find continue searching.
*)
procedure TFindEntry.Find(FindType : TFindType);

function NewListEntry(var AFileEntry : TFileEntry;
  ASector : Longint; AIndex : Integer) : Pointer;
var
  ListEntry : PFoundEntry;

begin
  New(ListEntry);
  Move(AFileEntry, ListEntry^.FileEntry, SizeOf(TFileEntry));
  ListEntry^.Sector := ASector;
  ListEntry^.Index := AIndex;

  NewListEntry := ListEntry;
end;

function CompareEntry(var E1, E2 : TFileEntry) : Boolean;
begin
  if Initializing then
    CompareEntry := ( MemCmp(E1.Name, E2.Name, SizeOf(E1.Name)) = 0 ) and
                    (( E2.Attr and Directory ) = Directory )
  else
    CompareEntry := Compare(E1, E2);
end;

var
  I         : Integer;
  Sec       : Longint;
  BasicSec  : Longint;
  Cluster   : Word;
  lastEntry : Boolean;

begin      (* TFindEntry.Find *)
  RunError := refNoError;

  if List = nil then Exit;

  if FindType = FirstFind then
  begin
    FindError := fefNoError;

    ListIndex := 0;

    ClearList;

    Cluster := ((StartSec - BootInfo^.DiskLoc.Data) div BootInfo^.Boot.SPC) + 2;
    BasicSec := BootInfo^.DiskLoc.Data + Longint(Cluster - 2) * BootInfo^.Boot.SPC;
    Sec := StartSec;

    lastEntry := False;
    repeat
      if AbsRead(Drive, 1, Sec, DataSec^) = 0 then
      begin
        I := 0;
        while (I < MaxFileEntry) and (DataSec^[I].Name[0] <> #0) do
        begin
          if CompareEntry(FileEntry^, DataSec^[I]) then
            List^.Insert(NewListEntry(DataSec^[I], Sec, I));

          Inc(I);
        end;

        (* modified by KO Myung-Hun to recognize last entry correctly *)
        Inc(Sec);
        if sec = bootInfo^.diskLoc.data then
            lastEntry := True
        else if (Sec - BasicSec) = BootInfo^.Boot.SPC then
        begin
          Cluster := NextFAT(BootInfo^.DiskLoc.FAT1st, Cluster);
          lastEntry := cluster >= LLastCluster;

          BasicSec := BootInfo^.DiskLoc.Data + Longint(Cluster - 2) * BootInfo^.Boot.SPC;
          Sec := BasicSec;
        end;
      end
      else
      begin
        RunError := refRead;
        FindError := fefNotFound;
        Exit;
      end;

    (* modified by KO Myung-Hun to recognize last entry correctly *)
    until ((I < MaxFileEntry) and (DataSec^[I].Name[0] = #0)) or
           lastEntry;
  end;

  if List^.Count = 0 then
  begin
    FindError := fefNotFound;
    Exit;
  end;

  if (FindType = NextFind) and ((FindError and fefNoMore) = 0) then
    Inc(ListIndex);

  if List^.Count <= ListIndex then
  begin
    FindError := fefNoMore;
    Exit;
  end;

  Move(List^.At(ListIndex)^, FoundEntry^, SizeOf(TFoundEntry));
end;

procedure TFindEntry.Setup;
var
  Name     : string;
  FindName : TFCBName;
  Position : Byte;

begin
  Initializing := True;

  Name := Dir^;
  Delete(Name, 1, 3);

  Move(FileEntry^.Name, FindName, SizeOf(TFCBName));

  Position := Pos('\', Name);
  StartSec := BootInfo^.DiskLoc.Root;

  FindError := fefNoError;
  while (FindError = fefNoError) and (Position > 0) do
  begin
    Han2FCB(Copy(Name, 1, Position - 1), FileEntry^.Name);

    Find(FirstFind);

    if RunError <> refNoError then
    begin
      Stop := True;
      Exit;
    end;

    StartSec := BootInfo^.DiskLoc.Data + Longint(FoundEntry^.FileEntry.Cluster - 2) *
      BootInfo^.Boot.SPC;
    Delete(Name, 1, Position);
    Position := Pos('\', Name);
  end;

  if FindError = fefNoError then
    Move(FindName, FileEntry^.Name, SizeOf(TFCBName))
  else
    Stop := True;

  ClearFoundEntry;

  Initializing := False;
end;

constructor TFindFile.Init(APath : string; Attrib : Byte);
var
  AFileEntry : TFileEntry;
  D, N, E    : string;

begin
  Path := NewStr(FExpand(APath));

  FSplit(Path^, D, N, E);
  Han2FCB(N + E, AFileEntry.Name);
  AFileEntry.Attr := Attrib;

  Name := NewStr(N + E);

  if not TFindEntry.Init(D, AFileEntry) then
    Fail;
end;

destructor TFindFile.Done;
begin
  TFindEntry.Done;

  if Path <> nil then
    DisposeStr(Path);

  if Name <> nil then
    DisposeStr(Name);
end;

procedure TFindFile.SetDir(ADir : string);
begin
  if Stop then
    Exit;

  ADir := FExpand(ADir);
  while ( Length( ADir ) > 2 ) and ( ADir[ Length( ADir )] = '\' ) do
    Dec( ADir[ 0 ]);
  ADir := ADir + '\';

  SetPath(ADir + Name^);
end;

procedure TFindFile.SetPath(APath : string);
var
  AFileEntry : TFileEntry;
  D, N, E    : string;

begin
  if Stop then
    Exit;

  if Path <> nil then
    DisposeStr(Path);

  if Name <> nil then
    DisposeStr(Name);

  Path := NewStr(FExpand(APath));
  FSplit(Path^, D, N, E);

  Name := NewStr(N + E);

  Move(FileEntry^, AFileEntry, SizeOf(TFileEntry));
  Han2FCB(N + E, AFileEntry.Name);

  TFindEntry.SetDir(D);
  SetFileEntry(AFileEntry);
end;

procedure TFindFile.SetName( aName : string );
var
  AFileEntry : TFileEntry;

begin
    if Stop then
        Exit;

    if Path <> nil then
        DisposeStr(Path);

    if Name <> nil then
        DisposeStr(Name);

    Name := NewStr( UCase( aName ));
    Path := NewStr( FExpand( fnMerge( Dir^, Name^)));

    Move(FileEntry^, AFileEntry, SizeOf(TFileEntry));
    Han2FCB( Name^, AFileEntry.Name );

    SetFileEntry(AFileEntry);
end;

procedure TFindFile.SetAttr(Attrib : Byte);
var
  AFileEntry : TFileEntry;

begin
  if Stop then
    Exit;

  Move(FileEntry^, AFileEntry, SizeOf(TFileEntry));
  AFileEntry.Attr := Attrib;

  SetFileEntry(AFileEntry);
end;

function TFindFile.Compare(var E1, E2 : TFileEntry) : Boolean;
var
  I : Integer;

begin
  I := 0;
  while (I < 11) and ((E1.Name[I] = E2.Name[I]) or (E1.Name[I] = '?')) do
    Inc(I);

  Compare := False;
  if ( I = 11 ) and
     (((E1.Attr and E2.Attr) <> 0 ) or (E1.Attr = AnyFile)) then
    Compare := True
end;

constructor TVFATFindFile.Init( APath : string; Attrib : Byte );
begin
    New( FileEntry );
    New( FoundEntry );
    if ( FileEntry = nil ) or ( FoundEntry = nil ) then
        Fail;

    Path := NewStr( FExpand( APath ));
    dir := NewStr( getDirCom( path^ ));
    name := NewStr( getNameCom( path^ ));
    ShortDir := nil;
    FF := nil;
    fat := nil;

    fileEntry^.fileEntry.attr := Attrib;

    Setup;
end;

destructor TVFATFindFile.Done;
begin
    if FF <> nil then
        Dispose( FF, Done );

    if FileEntry <> nil then
        Dispose( FileEntry );

    if FoundEntry <> nil then
        Dispose( FoundEntry );

    if Path <> nil then
        DisposeStr( Path );

    if dir <> nil then
        DisposeStr( dir );

    if name <> nil then
        DisposeStr( name );

    if ShortDir <> nil then
        DisposeStr( ShortDir );
end;

procedure TVFATFindFile.SetPath( APath : string );
begin
    setName( getNameCom( aPath ));
    setDir( getDirCom( aPath ));
end;

procedure TVFATFindFile.setDir( aDir : string );
begin
    if path <> nil then
        DisposeStr( path );

    if dir <> nil then
        DisposeStr( dir );

    dir := NewStr( aDir );
    path := NewStr( fnMerge( dir^, name^ ));

    Setup;
end;

procedure TVFATFindFile.setName( aName : string );
begin
    if path <> nil then
        DisposeStr( path );

    if name <> nil then
        DisposeStr( name );

    name := NewStr( aName );
    path := NewStr( fnMerge( dir^, name^ ));

    fileEntry^.longName := name^;
    fileEntry^.shortName := Copy( name^, 1, 12 );
end;

procedure TVFATFindFile.SetAttr( Attrib : Byte );
begin
    fileEntry^.fileEntry.Attr := Attrib;
end;

procedure TVFATFindFile.Setup;
var
    APath               : string;
    ShortPath           : string;
    Position            : Integer;
    OldAttr             : Byte;

begin
    RunError := refNoError;
    FindError := fefNoError;

    APath := FExpand( Path^ );
    ShortPath := Copy( APath, 1, 2 );

    OldAttr := fileEntry^.fileEntry.attr;

    if FF <> nil then
        Dispose( FF, Done );

    FF := New( PFindFile, Init( Copy( APath, 1, 3 ) + '*.*', AnyFile ));
    Delete( APath, 1, 3 );

    Position := Pos( '\', APath );
    FindError := fefNoError;
    while ( Position > 0 ) and ( FindError = fefNoError ) do
    begin
        FileEntry^.LongName := Copy( APath, 1, Position - 1 );
        FileEntry^.ShortName := FileEntry^.LongName;
        FileEntry^.FileEntry.Attr := Directory;

        Find( FirstFind );

        ShortPath := ShortPath + '\' + FoundEntry^.VFATFileEntry.ShortName;
        FF^.SetDir( ShortPath );

        Delete( APath, 1, Position );
        Position := Pos( '\', APath );
    end;

    if FindError = fefNoError then
    begin
        FileEntry^.LongName := APath;
        FileEntry^.ShortName := Copy( APath, 1, 12 );
        FileEntry^.FileEntry.Attr := oldAttr;

        if ShortDir <> nil then
            DisposeStr( ShortDir );

        ShortDir := NewStr( FF^.Dir^ );
    end;

    StartSec := FF^.StartSec;
    fat := ff;
end;

procedure TVFATFindFile.Find( FindType : TFindType );
var
    VFE    : TVFATFileEntry;
    Sector : Longint;
    Index  : Integer;

begin
    FindError := fefNoError;

    if FindType = FirstFind then
        FF^.FindFirst
    else
        FF^.FindNext;

    while FF^.FindError = fefNoError do
    begin
        if FF^.FoundEntry^.FileEntry.Name[ 0 ] <> #$E5 then
        begin
            Sector := FF^.FoundEntry^.Sector;
            Index := FF^.FoundEntry^.Index;

            if FF^.FoundEntry^.FileEntry.Attr = AttrOfLongFile then
            begin
                VFE.CheckSum := FF^.FoundEntry^.FileEntry.Unused[ 1 ];
                VFE.LongName := GetLongName;
                VFE.ShortName := GetShortName;
            end
            else
            begin
                VFE.LongName := '';
                VFE.ShortName := GetShortName;
                VFE.CheckSum := 0;
            end;

            Move( FF^.FoundEntry^.FileEntry, VFE.FileEntry, SizeOf( TFileEntry ));

            if Compare( FileEntry^, VFE ) then
            begin
                Move( VFE, FoundEntry^.VFATFileEntry, SizeOf( TVFATFileEntry ));
                FoundEntry^.Sector := Sector;
                FoundEntry^.Index  := Index;
                FoundEntry^.Slots := (( Length( VFE.LongName ) + 12 ) div 13 ) + 1;
                Exit;
            end;
        end;

        FF^.FindNext;
    end;

    FindError := FF^.FindError;
end;

procedure TVFATFindFile.FindFirst;
begin
    Find( FirstFind );
end;

procedure TVFATFindFile.FindNext;
begin
    Find( NextFind );
end;

function TVFATFindFile.Compare( var E1, E2 : TVFATFileEntry ) : Boolean;
begin
    Compare := ( InSpec( UCase( E2.ShortName ), UCase( E1.LongName )) or
                 InSpec( UCase( E2.LongName ), UCase( E1.LongName ))) and
               ((( E1.FileEntry.Attr and E2.FileEntry.Attr ) <> 0 ) or
                ( E1.FileEntry.Attr = AnyFile ));
end;

(*
        Bug fixed on 1999.06.15

        Contents : this function always return FALSE because
                   file name is copyied to 0-based offset of ShortName.

        Written by KO Myung-Hun
*)

function TVFATFindFile.CheckSumOk : Boolean;
var
    ChkSum    : Byte;
    I         : Integer;
    ShortName : TShortName;

begin
    ShortName[ 0 ] := #11;
    Move( FoundEntry^.VFATFileEntry.FileEntry.Name, ShortName[ 1 ], 11 );

    ChkSum := 0;
    for I := 1 to 11 do
    begin
        ChkSum := ((( ChkSum and 1 ) shl 7 ) or
                   (( ChkSum and $FE ) shr 1 )) +
                   Ord( ShortName[ I ]);
    end;

    CheckSumOk := ChkSum = FoundEntry^.VFATFileEntry.CheckSum;
end;

function TVFATFindFile.GetName : string;
begin
    Result := FoundEntry^.VFATFileEntry.LongName;
    if Result = '' then
        Result := FoundEntry^.VFATFileEntry.ShortName;
end;

function TVFATFindFile.GetLongName : TLongName;
var
    I       : Integer;
    Index   : Integer;
    slot    : TVFATSlot;

begin
    repeat
        Move( FF^.FoundEntry^.FileEntry, slot, SizeOf( slot ));

        Index := slot.id - Ord( 'A' );
        if Index < 0 then
            Index := Pred( slot.id );

        Index := Index * 13 + 1;

        for I := 0 to 4 do
        begin
            Result[ Index * 2 - 1 ] := slot.name0_4[ I * 2 ];
            Result[ Index * 2 ] := slot.name0_4[ I * 2 + 1 ];
            Inc( Index );
        end;

        for I := 0 to 5 do
        begin
            Result[ Index * 2 - 1 ] := slot.name5_10[ I * 2 ];
            Result[ Index * 2 ] := slot.name5_10[ I * 2 + 1 ];
            Inc( Index );
        end;

        for I := 0 to 1 do
        begin
            Result[ Index * 2 - 1 ] := slot.name11_12[ I * 2 ];
            Result[ Index * 2 ] := slot.name11_12[ I * 2 + 1 ];
            Inc( Index );
        end;

        FF^.FindNext;
    until  slot.id in [ 1, Ord( 'A' )];

    Result[ 0 ] := #255;
    Result[ 0 ] := Chr( Pos( #0#0, Result ));
    if Length( Result ) = 0 then
        Result[ 0 ] := Chr( Pred( Index ) * 2 )
    else
        Result[ 0 ] := Pred( Result[ 0 ]);

    result := uni2asc( result );
end;

function TVFATFindFile.GetShortName : TShortName;
begin
    GetShortName := FCB2Han( FF^.FoundEntry^.FileEntry.Name );
end;

type
    PUnicodeValue = ^TUnicodeValue;
    TUnicodeValue = record
        uni1 : Byte;
        uni2 : Byte;
    end;

const
    fatCode2uni : array [ 0..255 ] of Byte =
    (
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $3e, $ff, $3f, $ff, $ff,
        $00, $01, $02, $03, $04, $05, $06, $07,
        $08, $09, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $0a, $0b, $0c, $0d, $0e, $0f, $10,
        $11, $12, $13, $14, $15, $16, $17, $18,
        $19, $1a, $1b, $1c, $1d, $1e, $1f, $20,
        $21, $22, $23, $ff, $ff, $ff, $ff, $ff,
        $ff, $24, $25, $26, $27, $28, $29, $2a,
        $2b, $2c, $2d, $2e, $2f, $30, $31, $32,
        $33, $34, $35, $36, $37, $38, $39, $3a,
        $3b, $3c, $3d, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff,
        $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    );

    fatAsc2uni : array [ 0..255 ] of TUnicodeValue =
    (
        (* $00 *)
        (uni1:$00; uni2:$00), (uni1:$01; uni2:$00), (uni1:$02; uni2:$00), (uni1:$03; uni2:$00),
        (uni1:$04; uni2:$00), (uni1:$05; uni2:$00), (uni1:$06; uni2:$00), (uni1:$07; uni2:$00),
        (uni1:$08; uni2:$00), (uni1:$09; uni2:$00), (uni1:$0A; uni2:$00), (uni1:$0B; uni2:$00),
        (uni1:$0C; uni2:$00), (uni1:$0D; uni2:$00), (uni1:$0E; uni2:$00), (uni1:$0F; uni2:$00),
        (* $10 *)
        (uni1:$10; uni2:$00), (uni1:$11; uni2:$00), (uni1:$12; uni2:$00), (uni1:$13; uni2:$00),
        (uni1:$14; uni2:$00), (uni1:$15; uni2:$00), (uni1:$16; uni2:$00), (uni1:$17; uni2:$00),
        (uni1:$18; uni2:$00), (uni1:$19; uni2:$00), (uni1:$1A; uni2:$00), (uni1:$1B; uni2:$00),
        (uni1:$1C; uni2:$00), (uni1:$1D; uni2:$00), (uni1:$1E; uni2:$00), (uni1:$1F; uni2:$00),
        (* $20 *)
        (uni1:$20; uni2:$00), (uni1:$21; uni2:$00), (uni1:$22; uni2:$00), (uni1:$23; uni2:$00),
        (uni1:$24; uni2:$00), (uni1:$25; uni2:$00), (uni1:$26; uni2:$00), (uni1:$27; uni2:$00),
        (uni1:$28; uni2:$00), (uni1:$29; uni2:$00), (uni1:$2A; uni2:$00), (uni1:$2B; uni2:$00),
        (uni1:$2C; uni2:$00), (uni1:$2D; uni2:$00), (uni1:$2E; uni2:$00), (uni1:$2F; uni2:$00),
        (* $30 *)
        (uni1:$30; uni2:$00), (uni1:$31; uni2:$00), (uni1:$32; uni2:$00), (uni1:$33; uni2:$00),
        (uni1:$34; uni2:$00), (uni1:$35; uni2:$00), (uni1:$36; uni2:$00), (uni1:$37; uni2:$00),
        (uni1:$38; uni2:$00), (uni1:$39; uni2:$00), (uni1:$3A; uni2:$00), (uni1:$3B; uni2:$00),
        (uni1:$3C; uni2:$00), (uni1:$3D; uni2:$00), (uni1:$3E; uni2:$00), (uni1:$3F; uni2:$00),
        (* $40 *)
        (uni1:$40; uni2:$00), (uni1:$41; uni2:$00), (uni1:$42; uni2:$00), (uni1:$43; uni2:$00),
        (uni1:$44; uni2:$00), (uni1:$45; uni2:$00), (uni1:$46; uni2:$00), (uni1:$47; uni2:$00),
        (uni1:$48; uni2:$00), (uni1:$49; uni2:$00), (uni1:$4A; uni2:$00), (uni1:$4B; uni2:$00),
        (uni1:$4C; uni2:$00), (uni1:$4D; uni2:$00), (uni1:$4E; uni2:$00), (uni1:$4F; uni2:$00),
        (* $50 *)
        (uni1:$50; uni2:$00), (uni1:$51; uni2:$00), (uni1:$52; uni2:$00), (uni1:$53; uni2:$00),
        (uni1:$54; uni2:$00), (uni1:$55; uni2:$00), (uni1:$56; uni2:$00), (uni1:$57; uni2:$00),
        (uni1:$58; uni2:$00), (uni1:$59; uni2:$00), (uni1:$5A; uni2:$00), (uni1:$5B; uni2:$00),
        (uni1:$5C; uni2:$00), (uni1:$5D; uni2:$00), (uni1:$5E; uni2:$00), (uni1:$5F; uni2:$00),
        (* $60 *)
        (uni1:$60; uni2:$00), (uni1:$61; uni2:$00), (uni1:$62; uni2:$00), (uni1:$63; uni2:$00),
        (uni1:$64; uni2:$00), (uni1:$65; uni2:$00), (uni1:$66; uni2:$00), (uni1:$67; uni2:$00),
        (uni1:$68; uni2:$00), (uni1:$69; uni2:$00), (uni1:$6A; uni2:$00), (uni1:$6B; uni2:$00),
        (uni1:$6C; uni2:$00), (uni1:$6D; uni2:$00), (uni1:$6E; uni2:$00), (uni1:$6F; uni2:$00),
        (* $70 *)
        (uni1:$70; uni2:$00), (uni1:$71; uni2:$00), (uni1:$72; uni2:$00), (uni1:$73; uni2:$00),
        (uni1:$74; uni2:$00), (uni1:$75; uni2:$00), (uni1:$76; uni2:$00), (uni1:$77; uni2:$00),
        (uni1:$78; uni2:$00), (uni1:$79; uni2:$00), (uni1:$7A; uni2:$00), (uni1:$7B; uni2:$00),
        (uni1:$7C; uni2:$00), (uni1:$7D; uni2:$00), (uni1:$7E; uni2:$00), (uni1:$7F; uni2:$00),
        (* $80 *)
        (uni1:$C7; uni2:$00), (uni1:$FC; uni2:$00), (uni1:$E9; uni2:$00), (uni1:$E2; uni2:$00),
        (uni1:$E4; uni2:$00), (uni1:$E0; uni2:$00), (uni1:$E5; uni2:$00), (uni1:$E7; uni2:$00),
        (uni1:$EA; uni2:$00), (uni1:$EB; uni2:$00), (uni1:$E8; uni2:$00), (uni1:$EF; uni2:$00),
        (uni1:$EE; uni2:$00), (uni1:$EC; uni2:$00), (uni1:$C4; uni2:$00), (uni1:$C5; uni2:$00),
        (* $90 *)
        (uni1:$C9; uni2:$00), (uni1:$E6; uni2:$00), (uni1:$C6; uni2:$00), (uni1:$F4; uni2:$00),
        (uni1:$F6; uni2:$00), (uni1:$F2; uni2:$00), (uni1:$FB; uni2:$00), (uni1:$F9; uni2:$00),
        (uni1:$FF; uni2:$00), (uni1:$D6; uni2:$00), (uni1:$DC; uni2:$00), (uni1:$F8; uni2:$00),
        (uni1:$A3; uni2:$00), (uni1:$D8; uni2:$00), (uni1:$D7; uni2:$00), (uni1:$92; uni2:$00),
        (* $A0 *)
        (uni1:$E1; uni2:$00), (uni1:$E0; uni2:$00), (uni1:$F3; uni2:$00), (uni1:$FA; uni2:$00),
        (uni1:$F1; uni2:$00), (uni1:$D1; uni2:$00), (uni1:$AA; uni2:$00), (uni1:$BA; uni2:$00),
        (uni1:$BF; uni2:$00), (uni1:$AE; uni2:$00), (uni1:$AC; uni2:$00), (uni1:$BD; uni2:$00),
        (uni1:$BC; uni2:$00), (uni1:$A1; uni2:$00), (uni1:$AB; uni2:$00), (uni1:$BB; uni2:$00),
        (* $B0 *)
        (uni1:$91; uni2:$25), (uni1:$92; uni2:$25), (uni1:$93; uni2:$25), (uni1:$02; uni2:$25),
        (uni1:$24; uni2:$25), (uni1:$C1; uni2:$00), (uni1:$C2; uni2:$00), (uni1:$C0; uni2:$00),
        (uni1:$A9; uni2:$00), (uni1:$63; uni2:$25), (uni1:$51; uni2:$25), (uni1:$57; uni2:$25),
        (uni1:$5D; uni2:$25), (uni1:$A2; uni2:$00), (uni1:$A5; uni2:$00), (uni1:$10; uni2:$25),
        (* $C0 *)
        (uni1:$14; uni2:$25), (uni1:$34; uni2:$25), (uni1:$2C; uni2:$25), (uni1:$1C; uni2:$25),
        (uni1:$00; uni2:$25), (uni1:$3C; uni2:$25), (uni1:$E3; uni2:$00), (uni1:$C3; uni2:$00),
        (uni1:$5A; uni2:$25), (uni1:$54; uni2:$25), (uni1:$69; uni2:$25), (uni1:$66; uni2:$25),
        (uni1:$60; uni2:$25), (uni1:$50; uni2:$25), (uni1:$6C; uni2:$25), (uni1:$A4; uni2:$00),
        (* $D0 *)
        (uni1:$F0; uni2:$00), (uni1:$D0; uni2:$00), (uni1:$CA; uni2:$00), (uni1:$CB; uni2:$00),
        (uni1:$C8; uni2:$00), (uni1:$31; uni2:$01), (uni1:$CD; uni2:$00), (uni1:$CE; uni2:$00),
        (uni1:$CF; uni2:$00), (uni1:$18; uni2:$25), (uni1:$0C; uni2:$25), (uni1:$88; uni2:$25),
        (uni1:$84; uni2:$25), (uni1:$A6; uni2:$00), (uni1:$CC; uni2:$00), (uni1:$80; uni2:$25),
        (* $E0 *)
        (uni1:$D3; uni2:$00), (uni1:$DF; uni2:$00), (uni1:$D4; uni2:$00), (uni1:$D2; uni2:$00),
        (uni1:$F5; uni2:$00), (uni1:$D5; uni2:$00), (uni1:$B5; uni2:$00), (uni1:$FE; uni2:$00),
        (uni1:$DE; uni2:$00), (uni1:$DA; uni2:$00), (uni1:$DB; uni2:$00), (uni1:$D9; uni2:$00),
        (uni1:$FD; uni2:$00), (uni1:$DD; uni2:$00), (uni1:$AF; uni2:$00), (uni1:$B4; uni2:$00),
        (* $F0 *)
        (uni1:$AD; uni2:$00), (uni1:$B1; uni2:$00), (uni1:$17; uni2:$20), (uni1:$BE; uni2:$00),
        (uni1:$B6; uni2:$00), (uni1:$A7; uni2:$00), (uni1:$F7; uni2:$00), (uni1:$B8; uni2:$00),
        (uni1:$B0; uni2:$00), (uni1:$A8; uni2:$00), (uni1:$B7; uni2:$00), (uni1:$B9; uni2:$00),
        (uni1:$B3; uni2:$00), (uni1:$B2; uni2:$00), (uni1:$A0; uni2:$25), (uni1:$A0; uni2:$00)
    );

type
    PCodeArray = ^TCodeArray;
    TCodeArray = array [ 0..255 ] of Byte;

const
    fatUni2code : array [ 0..63 ] of Char =
    (
        '0', '1', '2', '3', '4', '5', '6', '7',
        '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
        'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
        'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd',
        'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l',
        'm', 'n', 'o', 'p', 'q', 'r', 's', 't',
        'u', 'v', 'w', 'x', 'y', 'z', '+', '-'
    );

(*
    유니코드2.0에서 0xAC00 - 0xACFF ('가' - '과ㄱㅅ')에 대한 완성형
    코드값 대응.
    (완성형 코드, 유니코드)형식이다
*)
    fatHK2U : array [ 0..4699 ] of Word =
    (
        $B0A1, $AC00, $B0A2, $AC01, $B0A3, $AC04, $B0A4, $AC07,
        $B0A5, $AC08, $B0A6, $AC09, $B0A7, $AC0A, $B0A8, $AC10,
        $B0A9, $AC11, $B0AA, $AC12, $B0AB, $AC13, $B0AC, $AC14,
        $B0AD, $AC15, $B0AE, $AC16, $B0AF, $AC17, $B0B0, $AC19,
        $B0B1, $AC1A, $B0B2, $AC1B, $B0B3, $AC1C, $B0B4, $AC1D,
        $B0B5, $AC20, $B0B6, $AC24, $B0B7, $AC2C, $B0B8, $AC2D,
        $B0B9, $AC2F, $B0BA, $AC30, $B0BB, $AC31, $B0BC, $AC38,
        $B0BD, $AC39, $B0BE, $AC3C, $B0BF, $AC40, $B0C0, $AC4B,
        $B0C1, $AC4D, $B0C2, $AC54, $B0C3, $AC58, $B0C4, $AC5C,
        $B0C5, $AC70, $B0C6, $AC71, $B0C7, $AC74, $B0C8, $AC77,
        $B0C9, $AC78, $B0CA, $AC7A, $B0CB, $AC80, $B0CC, $AC81,
        $B0CD, $AC83, $B0CE, $AC84, $B0CF, $AC85, $B0D0, $AC86,
        $B0D1, $AC89, $B0D2, $AC8A, $B0D3, $AC8B, $B0D4, $AC8C,
        $B0D5, $AC90, $B0D6, $AC94, $B0D7, $AC9C, $B0D8, $AC9D,
        $B0D9, $AC9F, $B0DA, $ACA0, $B0DB, $ACA1, $B0DC, $ACA8,
        $B0DD, $ACA9, $B0DE, $ACAA, $B0DF, $ACAC, $B0E0, $ACAF,
        $B0E1, $ACB0, $B0E2, $ACB8, $B0E3, $ACB9, $B0E4, $ACBB,
        $B0E5, $ACBC, $B0E6, $ACBD, $B0E7, $ACC1, $B0E8, $ACC4,
        $B0E9, $ACC8, $B0EA, $ACCC, $B0EB, $ACD5, $B0EC, $ACD7,
        $B0ED, $ACE0, $B0EE, $ACE1, $B0EF, $ACE4, $B0F0, $ACE7,
        $B0F1, $ACE8, $B0F2, $ACEA, $B0F3, $ACEC, $B0F4, $ACEF,
        $B0F5, $ACF0, $B0F6, $ACF1, $B0F7, $ACF3, $B0F8, $ACF5,
        $B0F9, $ACF6, $B0FA, $ACFC, $B0FB, $ACFD, $B0FC, $AD00,
        $B0FD, $AD04, $B0FE, $AD06, $B1A1, $AD0C, $B1A2, $AD0D,
        $B1A3, $AD0F, $B1A4, $AD11, $B1A5, $AD18, $B1A6, $AD1C,
        $B1A7, $AD20, $B1A8, $AD29, $B1A9, $AD2C, $B1AA, $AD2D,
        $B1AB, $AD34, $B1AC, $AD35, $B1AD, $AD38, $B1AE, $AD3C,
        $B1AF, $AD44, $B1B0, $AD45, $B1B1, $AD47, $B1B2, $AD49,
        $B1B3, $AD50, $B1B4, $AD54, $B1B5, $AD58, $B1B6, $AD61,
        $B1B7, $AD63, $B1B8, $AD6C, $B1B9, $AD6D, $B1BA, $AD70,
        $B1BB, $AD73, $B1BC, $AD74, $B1BD, $AD75, $B1BE, $AD76,
        $B1BF, $AD7B, $B1C0, $AD7C, $B1C1, $AD7D, $B1C2, $AD7F,
        $B1C3, $AD81, $B1C4, $AD82, $B1C5, $AD88, $B1C6, $AD89,
        $B1C7, $AD8C, $B1C8, $AD90, $B1C9, $AD9C, $B1CA, $AD9D,
        $B1CB, $ADA4, $B1CC, $ADB7, $B1CD, $ADC0, $B1CE, $ADC1,
        $B1CF, $ADC4, $B1D0, $ADC8, $B1D1, $ADD0, $B1D2, $ADD1,
        $B1D3, $ADD3, $B1D4, $ADDC, $B1D5, $ADE0, $B1D6, $ADE4,
        $B1D7, $ADF8, $B1D8, $ADF9, $B1D9, $ADFC, $B1DA, $ADFF,
        $B1DB, $AE00, $B1DC, $AE01, $B1DD, $AE08, $B1DE, $AE09,
        $B1DF, $AE0B, $B1E0, $AE0D, $B1E1, $AE14, $B1E2, $AE30,
        $B1E3, $AE31, $B1E4, $AE34, $B1E5, $AE37, $B1E6, $AE38,
        $B1E7, $AE3A, $B1E8, $AE40, $B1E9, $AE41, $B1EA, $AE43,
        $B1EB, $AE45, $B1EC, $AE46, $B1ED, $AE4A, $B1EE, $AE4C,
        $B1EF, $AE4D, $B1F0, $AE4E, $B1F1, $AE50, $B1F2, $AE54,
        $B1F3, $AE56, $B1F4, $AE5C, $B1F5, $AE5D, $B1F6, $AE5F,
        $B1F7, $AE60, $B1F8, $AE61, $B1F9, $AE65, $B1FA, $AE68,
        $B1FB, $AE69, $B1FC, $AE6C, $B1FD, $AE70, $B1FE, $AE78,
        $B2A1, $AE79, $B2A2, $AE7B, $B2A3, $AE7C, $B2A4, $AE7D,
        $B2A5, $AE84, $B2A6, $AE85, $B2A7, $AE8C, $B2A8, $AEBC,
        $B2A9, $AEBD, $B2AA, $AEBE, $B2AB, $AEC0, $B2AC, $AEC4,
        $B2AD, $AECC, $B2AE, $AECD, $B2AF, $AECF, $B2B0, $AED0,
        $B2B1, $AED1, $B2B2, $AED8, $B2B3, $AED9, $B2B4, $AEDC,
        $B2B5, $AEE8, $B2B6, $AEEB, $B2B7, $AEED, $B2B8, $AEF4,
        $B2B9, $AEF8, $B2BA, $AEFC, $B2BB, $AF07, $B2BC, $AF08,
        $B2BD, $AF0D, $B2BE, $AF10, $B2BF, $AF2C, $B2C0, $AF2D,
        $B2C1, $AF30, $B2C2, $AF32, $B2C3, $AF34, $B2C4, $AF3C,
        $B2C5, $AF3D, $B2C6, $AF3F, $B2C7, $AF41, $B2C8, $AF42,
        $B2C9, $AF43, $B2CA, $AF48, $B2CB, $AF49, $B2CC, $AF50,
        $B2CD, $AF5C, $B2CE, $AF5D, $B2CF, $AF64, $B2D0, $AF65,
        $B2D1, $AF79, $B2D2, $AF80, $B2D3, $AF84, $B2D4, $AF88,
        $B2D5, $AF90, $B2D6, $AF91, $B2D7, $AF95, $B2D8, $AF9C,
        $B2D9, $AFB8, $B2DA, $AFB9, $B2DB, $AFBC, $B2DC, $AFC0,
        $B2DD, $AFC7, $B2DE, $AFC8, $B2DF, $AFC9, $B2E0, $AFCB,
        $B2E1, $AFCD, $B2E2, $AFCE, $B2E3, $AFD4, $B2E4, $AFDC,
        $B2E5, $AFE8, $B2E6, $AFE9, $B2E7, $AFF0, $B2E8, $AFF1,
        $B2E9, $AFF4, $B2EA, $AFF8, $B2EB, $B000, $B2EC, $B001,
        $B2ED, $B004, $B2EE, $B00C, $B2EF, $B010, $B2F0, $B014,
        $B2F1, $B01C, $B2F2, $B01D, $B2F3, $B028, $B2F4, $B044,
        $B2F5, $B045, $B2F6, $B048, $B2F7, $B04A, $B2F8, $B04C,
        $B2F9, $B04E, $B2FA, $B053, $B2FB, $B054, $B2FC, $B055,
        $B2FD, $B057, $B2FE, $B059, $B3A1, $B05D, $B3A2, $B07C,
        $B3A3, $B07D, $B3A4, $B080, $B3A5, $B084, $B3A6, $B08C,
        $B3A7, $B08D, $B3A8, $B08F, $B3A9, $B091, $B3AA, $B098,
        $B3AB, $B099, $B3AC, $B09A, $B3AD, $B09C, $B3AE, $B09F,
        $B3AF, $B0A0, $B3B0, $B0A1, $B3B1, $B0A2, $B3B2, $B0A8,
        $B3B3, $B0A9, $B3B4, $B0AB, $B3B5, $B0AC, $B3B6, $B0AD,
        $B3B7, $B0AE, $B3B8, $B0AF, $B3B9, $B0B1, $B3BA, $B0B3,
        $B3BB, $B0B4, $B3BC, $B0B5, $B3BD, $B0B8, $B3BE, $B0BC,
        $B3BF, $B0C4, $B3C0, $B0C5, $B3C1, $B0C7, $B3C2, $B0C8,
        $B3C3, $B0C9, $B3C4, $B0D0, $B3C5, $B0D1, $B3C6, $B0D4,
        $B3C7, $B0D8, $B3C8, $B0E0, $B3C9, $B0E5, $B3CA, $B108,
        $B3CB, $B109, $B3CC, $B10B, $B3CD, $B10C, $B3CE, $B110,
        $B3CF, $B112, $B3D0, $B113, $B3D1, $B118, $B3D2, $B119,
        $B3D3, $B11B, $B3D4, $B11C, $B3D5, $B11D, $B3D6, $B123,
        $B3D7, $B124, $B3D8, $B125, $B3D9, $B128, $B3DA, $B12C,
        $B3DB, $B134, $B3DC, $B135, $B3DD, $B137, $B3DE, $B138,
        $B3DF, $B139, $B3E0, $B140, $B3E1, $B141, $B3E2, $B144,
        $B3E3, $B148, $B3E4, $B150, $B3E5, $B151, $B3E6, $B154,
        $B3E7, $B155, $B3E8, $B158, $B3E9, $B15C, $B3EA, $B160,
        $B3EB, $B178, $B3EC, $B179, $B3ED, $B17C, $B3EE, $B180,
        $B3EF, $B182, $B3F0, $B188, $B3F1, $B189, $B3F2, $B18B,
        $B3F3, $B18D, $B3F4, $B192, $B3F5, $B193, $B3F6, $B194,
        $B3F7, $B198, $B3F8, $B19C, $B3F9, $B1A8, $B3FA, $B1CC,
        $B3FB, $B1D0, $B3FC, $B1D4, $B3FD, $B1DC, $B3FE, $B1DD,
        $B4A1, $B1DF, $B4A2, $B1E8, $B4A3, $B1E9, $B4A4, $B1EC,
        $B4A5, $B1F0, $B4A6, $B1F9, $B4A7, $B1FB, $B4A8, $B1FD,
        $B4A9, $B204, $B4AA, $B205, $B4AB, $B208, $B4AC, $B20B,
        $B4AD, $B20C, $B4AE, $B214, $B4AF, $B215, $B4B0, $B217,
        $B4B1, $B219, $B4B2, $B220, $B4B3, $B234, $B4B4, $B23C,
        $B4B5, $B258, $B4B6, $B25C, $B4B7, $B260, $B4B8, $B268,
        $B4B9, $B269, $B4BA, $B274, $B4BB, $B275, $B4BC, $B27C,
        $B4BD, $B284, $B4BE, $B285, $B4BF, $B289, $B4C0, $B290,
        $B4C1, $B291, $B4C2, $B294, $B4C3, $B298, $B4C4, $B299,
        $B4C5, $B29A, $B4C6, $B2A0, $B4C7, $B2A1, $B4C8, $B2A3,
        $B4C9, $B2A5, $B4CA, $B2A6, $B4CB, $B2AA, $B4CC, $B2AC,
        $B4CD, $B2B0, $B4CE, $B2B4, $B4CF, $B2C8, $B4D0, $B2C9,
        $B4D1, $B2CC, $B4D2, $B2D0, $B4D3, $B2D2, $B4D4, $B2D8,
        $B4D5, $B2D9, $B4D6, $B2DB, $B4D7, $B2DD, $B4D8, $B2E2,
        $B4D9, $B2E4, $B4DA, $B2E5, $B4DB, $B2E6, $B4DC, $B2E8,
        $B4DD, $B2EB, $B4DE, $B2EC, $B4DF, $B2ED, $B4E0, $B2EE,
        $B4E1, $B2EF, $B4E2, $B2F3, $B4E3, $B2F4, $B4E4, $B2F5,
        $B4E5, $B2F7, $B4E6, $B2F8, $B4E7, $B2F9, $B4E8, $B2FA,
        $B4E9, $B2FB, $B4EA, $B2FF, $B4EB, $B300, $B4EC, $B301,
        $B4ED, $B304, $B4EE, $B308, $B4EF, $B310, $B4F0, $B311,
        $B4F1, $B313, $B4F2, $B314, $B4F3, $B315, $B4F4, $B31C,
        $B4F5, $B354, $B4F6, $B355, $B4F7, $B356, $B4F8, $B358,
        $B4F9, $B35B, $B4FA, $B35C, $B4FB, $B35E, $B4FC, $B35F,
        $B4FD, $B364, $B4FE, $B365, $B5A1, $B367, $B5A2, $B369,
        $B5A3, $B36B, $B5A4, $B36E, $B5A5, $B370, $B5A6, $B371,
        $B5A7, $B374, $B5A8, $B378, $B5A9, $B380, $B5AA, $B381,
        $B5AB, $B383, $B5AC, $B384, $B5AD, $B385, $B5AE, $B38C,
        $B5AF, $B390, $B5B0, $B394, $B5B1, $B3A0, $B5B2, $B3A1,
        $B5B3, $B3A8, $B5B4, $B3AC, $B5B5, $B3C4, $B5B6, $B3C5,
        $B5B7, $B3C8, $B5B8, $B3CB, $B5B9, $B3CC, $B5BA, $B3CE,
        $B5BB, $B3D0, $B5BC, $B3D4, $B5BD, $B3D5, $B5BE, $B3D7,
        $B5BF, $B3D9, $B5C0, $B3DB, $B5C1, $B3DD, $B5C2, $B3E0,
        $B5C3, $B3E4, $B5C4, $B3E8, $B5C5, $B3FC, $B5C6, $B410,
        $B5C7, $B418, $B5C8, $B41C, $B5C9, $B420, $B5CA, $B428,
        $B5CB, $B429, $B5CC, $B42B, $B5CD, $B434, $B5CE, $B450,
        $B5CF, $B451, $B5D0, $B454, $B5D1, $B458, $B5D2, $B460,
        $B5D3, $B461, $B5D4, $B463, $B5D5, $B465, $B5D6, $B46C,
        $B5D7, $B480, $B5D8, $B488, $B5D9, $B49D, $B5DA, $B4A4,
        $B5DB, $B4A8, $B5DC, $B4AC, $B5DD, $B4B5, $B5DE, $B4B7,
        $B5DF, $B4B9, $B5E0, $B4C0, $B5E1, $B4C4, $B5E2, $B4C8,
        $B5E3, $B4D0, $B5E4, $B4D5, $B5E5, $B4DC, $B5E6, $B4DD,
        $B5E7, $B4E0, $B5E8, $B4E3, $B5E9, $B4E4, $B5EA, $B4E6,
        $B5EB, $B4EC, $B5EC, $B4ED, $B5ED, $B4EF, $B5EE, $B4F1,
        $B5EF, $B4F8, $B5F0, $B514, $B5F1, $B515, $B5F2, $B518,
        $B5F3, $B51B, $B5F4, $B51C, $B5F5, $B524, $B5F6, $B525,
        $B5F7, $B527, $B5F8, $B528, $B5F9, $B529, $B5FA, $B52A,
        $B5FB, $B530, $B5FC, $B531, $B5FD, $B534, $B5FE, $B538,
        $B6A1, $B540, $B6A2, $B541, $B6A3, $B543, $B6A4, $B544,
        $B6A5, $B545, $B6A6, $B54B, $B6A7, $B54C, $B6A8, $B54D,
        $B6A9, $B550, $B6AA, $B554, $B6AB, $B55C, $B6AC, $B55D,
        $B6AD, $B55F, $B6AE, $B560, $B6AF, $B561, $B6B0, $B5A0,
        $B6B1, $B5A1, $B6B2, $B5A4, $B6B3, $B5A8, $B6B4, $B5AA,
        $B6B5, $B5AB, $B6B6, $B5B0, $B6B7, $B5B1, $B6B8, $B5B3,
        $B6B9, $B5B4, $B6BA, $B5B5, $B6BB, $B5BB, $B6BC, $B5BC,
        $B6BD, $B5BD, $B6BE, $B5C0, $B6BF, $B5C4, $B6C0, $B5CC,
        $B6C1, $B5CD, $B6C2, $B5CF, $B6C3, $B5D0, $B6C4, $B5D1,
        $B6C5, $B5D8, $B6C6, $B5EC, $B6C7, $B610, $B6C8, $B611,
        $B6C9, $B614, $B6CA, $B618, $B6CB, $B625, $B6CC, $B62C,
        $B6CD, $B634, $B6CE, $B648, $B6CF, $B664, $B6D0, $B668,
        $B6D1, $B69C, $B6D2, $B69D, $B6D3, $B6A0, $B6D4, $B6A4,
        $B6D5, $B6AB, $B6D6, $B6AC, $B6D7, $B6B1, $B6D8, $B6D4,
        $B6D9, $B6F0, $B6DA, $B6F4, $B6DB, $B6F8, $B6DC, $B700,
        $B6DD, $B701, $B6DE, $B705, $B6DF, $B728, $B6E0, $B729,
        $B6E1, $B72C, $B6E2, $B72F, $B6E3, $B730, $B6E4, $B738,
        $B6E5, $B739, $B6E6, $B73B, $B6E7, $B744, $B6E8, $B748,
        $B6E9, $B74C, $B6EA, $B754, $B6EB, $B755, $B6EC, $B760,
        $B6ED, $B764, $B6EE, $B768, $B6EF, $B770, $B6F0, $B771,
        $B6F1, $B773, $B6F2, $B775, $B6F3, $B77C, $B6F4, $B77D,
        $B6F5, $B780, $B6F6, $B784, $B6F7, $B78C, $B6F8, $B78D,
        $B6F9, $B78F, $B6FA, $B790, $B6FB, $B791, $B6FC, $B792,
        $B6FD, $B796, $B6FE, $B797, $B7A1, $B798, $B7A2, $B799,
        $B7A3, $B79C, $B7A4, $B7A0, $B7A5, $B7A8, $B7A6, $B7A9,
        $B7A7, $B7AB, $B7A8, $B7AC, $B7A9, $B7AD, $B7AA, $B7B4,
        $B7AB, $B7B5, $B7AC, $B7B8, $B7AD, $B7C7, $B7AE, $B7C9,
        $B7AF, $B7EC, $B7B0, $B7ED, $B7B1, $B7F0, $B7B2, $B7F4,
        $B7B3, $B7FC, $B7B4, $B7FD, $B7B5, $B7FF, $B7B6, $B800,
        $B7B7, $B801, $B7B8, $B807, $B7B9, $B808, $B7BA, $B809,
        $B7BB, $B80C, $B7BC, $B810, $B7BD, $B818, $B7BE, $B819,
        $B7BF, $B81B, $B7C0, $B81D, $B7C1, $B824, $B7C2, $B825,
        $B7C3, $B828, $B7C4, $B82C, $B7C5, $B834, $B7C6, $B835,
        $B7C7, $B837, $B7C8, $B838, $B7C9, $B839, $B7CA, $B840,
        $B7CB, $B844, $B7CC, $B851, $B7CD, $B853, $B7CE, $B85C,
        $B7CF, $B85D, $B7D0, $B860, $B7D1, $B864, $B7D2, $B86C,
        $B7D3, $B86D, $B7D4, $B86F, $B7D5, $B871, $B7D6, $B878,
        $B7D7, $B87C, $B7D8, $B88D, $B7D9, $B8A8, $B7DA, $B8B0,
        $B7DB, $B8B4, $B7DC, $B8B8, $B7DD, $B8C0, $B7DE, $B8C1,
        $B7DF, $B8C3, $B7E0, $B8C5, $B7E1, $B8CC, $B7E2, $B8D0,
        $B7E3, $B8D4, $B7E4, $B8DD, $B7E5, $B8DF, $B7E6, $B8E1,
        $B7E7, $B8E8, $B7E8, $B8E9, $B7E9, $B8EC, $B7EA, $B8F0,
        $B7EB, $B8F8, $B7EC, $B8F9, $B7ED, $B8FB, $B7EE, $B8FD,
        $B7EF, $B904, $B7F0, $B918, $B7F1, $B920, $B7F2, $B93C,
        $B7F3, $B93D, $B7F4, $B940, $B7F5, $B944, $B7F6, $B94C,
        $B7F7, $B94F, $B7F8, $B951, $B7F9, $B958, $B7FA, $B959,
        $B7FB, $B95C, $B7FC, $B960, $B7FD, $B968, $B7FE, $B969,
        $B8A1, $B96B, $B8A2, $B96D, $B8A3, $B974, $B8A4, $B975,
        $B8A5, $B978, $B8A6, $B97C, $B8A7, $B984, $B8A8, $B985,
        $B8A9, $B987, $B8AA, $B989, $B8AB, $B98A, $B8AC, $B98D,
        $B8AD, $B98E, $B8AE, $B9AC, $B8AF, $B9AD, $B8B0, $B9B0,
        $B8B1, $B9B4, $B8B2, $B9BC, $B8B3, $B9BD, $B8B4, $B9BF,
        $B8B5, $B9C1, $B8B6, $B9C8, $B8B7, $B9C9, $B8B8, $B9CC,
        $B8B9, $B9CE, $B8BA, $B9CF, $B8BB, $B9D0, $B8BC, $B9D1,
        $B8BD, $B9D2, $B8BE, $B9D8, $B8BF, $B9D9, $B8C0, $B9DB,
        $B8C1, $B9DD, $B8C2, $B9DE, $B8C3, $B9E1, $B8C4, $B9E3,
        $B8C5, $B9E4, $B8C6, $B9E5, $B8C7, $B9E8, $B8C8, $B9EC,
        $B8C9, $B9F4, $B8CA, $B9F5, $B8CB, $B9F7, $B8CC, $B9F8,
        $B8CD, $B9F9, $B8CE, $B9FA, $B8CF, $BA00, $B8D0, $BA01,
        $B8D1, $BA08, $B8D2, $BA15, $B8D3, $BA38, $B8D4, $BA39,
        $B8D5, $BA3C, $B8D6, $BA40, $B8D7, $BA42, $B8D8, $BA48,
        $B8D9, $BA49, $B8DA, $BA4B, $B8DB, $BA4D, $B8DC, $BA4E,
        $B8DD, $BA53, $B8DE, $BA54, $B8DF, $BA55, $B8E0, $BA58,
        $B8E1, $BA5C, $B8E2, $BA64, $B8E3, $BA65, $B8E4, $BA67,
        $B8E5, $BA68, $B8E6, $BA69, $B8E7, $BA70, $B8E8, $BA71,
        $B8E9, $BA74, $B8EA, $BA78, $B8EB, $BA83, $B8EC, $BA84,
        $B8ED, $BA85, $B8EE, $BA87, $B8EF, $BA8C, $B8F0, $BAA8,
        $B8F1, $BAA9, $B8F2, $BAAB, $B8F3, $BAAC, $B8F4, $BAB0,
        $B8F5, $BAB2, $B8F6, $BAB8, $B8F7, $BAB9, $B8F8, $BABB,
        $B8F9, $BABD, $B8FA, $BAC4, $B8FB, $BAC8, $B8FC, $BAD8,
        $B8FD, $BAD9, $B8FE, $BAFC, $B9A1, $BB00, $B9A2, $BB04,
        $B9A3, $BB0D, $B9A4, $BB0F, $B9A5, $BB11, $B9A6, $BB18,
        $B9A7, $BB1C, $B9A8, $BB20, $B9A9, $BB29, $B9AA, $BB2B,
        $B9AB, $BB34, $B9AC, $BB35, $B9AD, $BB36, $B9AE, $BB38,
        $B9AF, $BB3B, $B9B0, $BB3C, $B9B1, $BB3D, $B9B2, $BB3E,
        $B9B3, $BB44, $B9B4, $BB45, $B9B5, $BB47, $B9B6, $BB49,
        $B9B7, $BB4D, $B9B8, $BB4F, $B9B9, $BB50, $B9BA, $BB54,
        $B9BB, $BB58, $B9BC, $BB61, $B9BD, $BB63, $B9BE, $BB6C,
        $B9BF, $BB88, $B9C0, $BB8C, $B9C1, $BB90, $B9C2, $BBA4,
        $B9C3, $BBA8, $B9C4, $BBAC, $B9C5, $BBB4, $B9C6, $BBB7,
        $B9C7, $BBC0, $B9C8, $BBC4, $B9C9, $BBC8, $B9CA, $BBD0,
        $B9CB, $BBD3, $B9CC, $BBF8, $B9CD, $BBF9, $B9CE, $BBFC,
        $B9CF, $BBFF, $B9D0, $BC00, $B9D1, $BC02, $B9D2, $BC08,
        $B9D3, $BC09, $B9D4, $BC0B, $B9D5, $BC0C, $B9D6, $BC0D,
        $B9D7, $BC0F, $B9D8, $BC11, $B9D9, $BC14, $B9DA, $BC15,
        $B9DB, $BC16, $B9DC, $BC17, $B9DD, $BC18, $B9DE, $BC1B,
        $B9DF, $BC1C, $B9E0, $BC1D, $B9E1, $BC1E, $B9E2, $BC1F,
        $B9E3, $BC24, $B9E4, $BC25, $B9E5, $BC27, $B9E6, $BC29,
        $B9E7, $BC2D, $B9E8, $BC30, $B9E9, $BC31, $B9EA, $BC34,
        $B9EB, $BC38, $B9EC, $BC40, $B9ED, $BC41, $B9EE, $BC43,
        $B9EF, $BC44, $B9F0, $BC45, $B9F1, $BC49, $B9F2, $BC4C,
        $B9F3, $BC4D, $B9F4, $BC50, $B9F5, $BC5D, $B9F6, $BC84,
        $B9F7, $BC85, $B9F8, $BC88, $B9F9, $BC8B, $B9FA, $BC8C,
        $B9FB, $BC8E, $B9FC, $BC94, $B9FD, $BC95, $B9FE, $BC97,
        $BAA1, $BC99, $BAA2, $BC9A, $BAA3, $BCA0, $BAA4, $BCA1,
        $BAA5, $BCA4, $BAA6, $BCA7, $BAA7, $BCA8, $BAA8, $BCB0,
        $BAA9, $BCB1, $BAAA, $BCB3, $BAAB, $BCB4, $BAAC, $BCB5,
        $BAAD, $BCBC, $BAAE, $BCBD, $BAAF, $BCC0, $BAB0, $BCC4,
        $BAB1, $BCCD, $BAB2, $BCCF, $BAB3, $BCD0, $BAB4, $BCD1,
        $BAB5, $BCD5, $BAB6, $BCD8, $BAB7, $BCDC, $BAB8, $BCF4,
        $BAB9, $BCF5, $BABA, $BCF6, $BABB, $BCF8, $BABC, $BCFC,
        $BABD, $BD04, $BABE, $BD05, $BABF, $BD07, $BAC0, $BD09,
        $BAC1, $BD10, $BAC2, $BD14, $BAC3, $BD24, $BAC4, $BD2C,
        $BAC5, $BD40, $BAC6, $BD48, $BAC7, $BD49, $BAC8, $BD4C,
        $BAC9, $BD50, $BACA, $BD58, $BACB, $BD59, $BACC, $BD64,
        $BACD, $BD68, $BACE, $BD80, $BACF, $BD81, $BAD0, $BD84,
        $BAD1, $BD87, $BAD2, $BD88, $BAD3, $BD89, $BAD4, $BD8A,
        $BAD5, $BD90, $BAD6, $BD91, $BAD7, $BD93, $BAD8, $BD95,
        $BAD9, $BD99, $BADA, $BD9A, $BADB, $BD9C, $BADC, $BDA4,
        $BADD, $BDB0, $BADE, $BDB8, $BADF, $BDD4, $BAE0, $BDD5,
        $BAE1, $BDD8, $BAE2, $BDDC, $BAE3, $BDE9, $BAE4, $BDF0,
        $BAE5, $BDF4, $BAE6, $BDF8, $BAE7, $BE00, $BAE8, $BE03,
        $BAE9, $BE05, $BAEA, $BE0C, $BAEB, $BE0D, $BAEC, $BE10,
        $BAED, $BE14, $BAEE, $BE1C, $BAEF, $BE1D, $BAF0, $BE1F,
        $BAF1, $BE44, $BAF2, $BE45, $BAF3, $BE48, $BAF4, $BE4C,
        $BAF5, $BE4E, $BAF6, $BE54, $BAF7, $BE55, $BAF8, $BE57,
        $BAF9, $BE59, $BAFA, $BE5A, $BAFB, $BE5B, $BAFC, $BE60,
        $BAFD, $BE61, $BAFE, $BE64, $BBA1, $BE68, $BBA2, $BE6A,
        $BBA3, $BE70, $BBA4, $BE71, $BBA5, $BE73, $BBA6, $BE74,
        $BBA7, $BE75, $BBA8, $BE7B, $BBA9, $BE7C, $BBAA, $BE7D,
        $BBAB, $BE80, $BBAC, $BE84, $BBAD, $BE8C, $BBAE, $BE8D,
        $BBAF, $BE8F, $BBB0, $BE90, $BBB1, $BE91, $BBB2, $BE98,
        $BBB3, $BE99, $BBB4, $BEA8, $BBB5, $BED0, $BBB6, $BED1,
        $BBB7, $BED4, $BBB8, $BED7, $BBB9, $BED8, $BBBA, $BEE0,
        $BBBB, $BEE3, $BBBC, $BEE4, $BBBD, $BEE5, $BBBE, $BEEC,
        $BBBF, $BF01, $BBC0, $BF08, $BBC1, $BF09, $BBC2, $BF18,
        $BBC3, $BF19, $BBC4, $BF1B, $BBC5, $BF1C, $BBC6, $BF1D,
        $BBC7, $BF40, $BBC8, $BF41, $BBC9, $BF44, $BBCA, $BF48,
        $BBCB, $BF50, $BBCC, $BF51, $BBCD, $BF55, $BBCE, $BF94,
        $BBCF, $BFB0, $BBD0, $BFC5, $BBD1, $BFCC, $BBD2, $BFCD,
        $BBD3, $BFD0, $BBD4, $BFD4, $BBD5, $BFDC, $BBD6, $BFDF,
        $BBD7, $BFE1, $BBD8, $C03C, $BBD9, $C051, $BBDA, $C058,
        $BBDB, $C05C, $BBDC, $C060, $BBDD, $C068, $BBDE, $C069,
        $BBDF, $C090, $BBE0, $C091, $BBE1, $C094, $BBE2, $C098,
        $BBE3, $C0A0, $BBE4, $C0A1, $BBE5, $C0A3, $BBE6, $C0A5,
        $BBE7, $C0AC, $BBE8, $C0AD, $BBE9, $C0AF, $BBEA, $C0B0,
        $BBEB, $C0B3, $BBEC, $C0B4, $BBED, $C0B5, $BBEE, $C0B6,
        $BBEF, $C0BC, $BBF0, $C0BD, $BBF1, $C0BF, $BBF2, $C0C0,
        $BBF3, $C0C1, $BBF4, $C0C5, $BBF5, $C0C8, $BBF6, $C0C9,
        $BBF7, $C0CC, $BBF8, $C0D0, $BBF9, $C0D8, $BBFA, $C0D9,
        $BBFB, $C0DB, $BBFC, $C0DC, $BBFD, $C0DD, $BBFE, $C0E4,
        $BCA1, $C0E5, $BCA2, $C0E8, $BCA3, $C0EC, $BCA4, $C0F4,
        $BCA5, $C0F5, $BCA6, $C0F7, $BCA7, $C0F9, $BCA8, $C100,
        $BCA9, $C104, $BCAA, $C108, $BCAB, $C110, $BCAC, $C115,
        $BCAD, $C11C, $BCAE, $C11D, $BCAF, $C11E, $BCB0, $C11F,
        $BCB1, $C120, $BCB2, $C123, $BCB3, $C124, $BCB4, $C126,
        $BCB5, $C127, $BCB6, $C12C, $BCB7, $C12D, $BCB8, $C12F,
        $BCB9, $C130, $BCBA, $C131, $BCBB, $C136, $BCBC, $C138,
        $BCBD, $C139, $BCBE, $C13C, $BCBF, $C140, $BCC0, $C148,
        $BCC1, $C149, $BCC2, $C14B, $BCC3, $C14C, $BCC4, $C14D,
        $BCC5, $C154, $BCC6, $C155, $BCC7, $C158, $BCC8, $C15C,
        $BCC9, $C164, $BCCA, $C165, $BCCB, $C167, $BCCC, $C168,
        $BCCD, $C169, $BCCE, $C170, $BCCF, $C174, $BCD0, $C178,
        $BCD1, $C185, $BCD2, $C18C, $BCD3, $C18D, $BCD4, $C18E,
        $BCD5, $C190, $BCD6, $C194, $BCD7, $C196, $BCD8, $C19C,
        $BCD9, $C19D, $BCDA, $C19F, $BCDB, $C1A1, $BCDC, $C1A5,
        $BCDD, $C1A8, $BCDE, $C1A9, $BCDF, $C1AC, $BCE0, $C1B0,
        $BCE1, $C1BD, $BCE2, $C1C4, $BCE3, $C1C8, $BCE4, $C1CC,
        $BCE5, $C1D4, $BCE6, $C1D7, $BCE7, $C1D8, $BCE8, $C1E0,
        $BCE9, $C1E4, $BCEA, $C1E8, $BCEB, $C1F0, $BCEC, $C1F1,
        $BCED, $C1F3, $BCEE, $C1FC, $BCEF, $C1FD, $BCF0, $C200,
        $BCF1, $C204, $BCF2, $C20C, $BCF3, $C20D, $BCF4, $C20F,
        $BCF5, $C211, $BCF6, $C218, $BCF7, $C219, $BCF8, $C21C,
        $BCF9, $C21F, $BCFA, $C220, $BCFB, $C228, $BCFC, $C229,
        $BCFD, $C22B, $BCFE, $C22D, $BDA1, $C22F, $BDA2, $C231,
        $BDA3, $C232, $BDA4, $C234, $BDA5, $C248, $BDA6, $C250,
        $BDA7, $C251, $BDA8, $C254, $BDA9, $C258, $BDAA, $C260,
        $BDAB, $C265, $BDAC, $C26C, $BDAD, $C26D, $BDAE, $C270,
        $BDAF, $C274, $BDB0, $C27C, $BDB1, $C27D, $BDB2, $C27F,
        $BDB3, $C281, $BDB4, $C288, $BDB5, $C289, $BDB6, $C290,
        $BDB7, $C298, $BDB8, $C29B, $BDB9, $C29D, $BDBA, $C2A4,
        $BDBB, $C2A5, $BDBC, $C2A8, $BDBD, $C2AC, $BDBE, $C2AD,
        $BDBF, $C2B4, $BDC0, $C2B5, $BDC1, $C2B7, $BDC2, $C2B9,
        $BDC3, $C2DC, $BDC4, $C2DD, $BDC5, $C2E0, $BDC6, $C2E3,
        $BDC7, $C2E4, $BDC8, $C2EB, $BDC9, $C2EC, $BDCA, $C2ED,
        $BDCB, $C2EF, $BDCC, $C2F1, $BDCD, $C2F6, $BDCE, $C2F8,
        $BDCF, $C2F9, $BDD0, $C2FB, $BDD1, $C2FC, $BDD2, $C300,
        $BDD3, $C308, $BDD4, $C309, $BDD5, $C30C, $BDD6, $C30D,
        $BDD7, $C313, $BDD8, $C314, $BDD9, $C315, $BDDA, $C318,
        $BDDB, $C31C, $BDDC, $C324, $BDDD, $C325, $BDDE, $C328,
        $BDDF, $C329, $BDE0, $C345, $BDE1, $C368, $BDE2, $C369,
        $BDE3, $C36C, $BDE4, $C370, $BDE5, $C372, $BDE6, $C378,
        $BDE7, $C379, $BDE8, $C37C, $BDE9, $C37D, $BDEA, $C384,
        $BDEB, $C388, $BDEC, $C38C, $BDED, $C3C0, $BDEE, $C3D8,
        $BDEF, $C3D9, $BDF0, $C3DC, $BDF1, $C3DF, $BDF2, $C3E0,
        $BDF3, $C3E2, $BDF4, $C3E8, $BDF5, $C3E9, $BDF6, $C3ED,
        $BDF7, $C3F4, $BDF8, $C3F5, $BDF9, $C3F8, $BDFA, $C408,
        $BDFB, $C410, $BDFC, $C424, $BDFD, $C42C, $BDFE, $C430,
        $BEA1, $C434, $BEA2, $C43C, $BEA3, $C43D, $BEA4, $C448,
        $BEA5, $C464, $BEA6, $C465, $BEA7, $C468, $BEA8, $C46C,
        $BEA9, $C474, $BEAA, $C475, $BEAB, $C479, $BEAC, $C480,
        $BEAD, $C494, $BEAE, $C49C, $BEAF, $C4B8, $BEB0, $C4BC,
        $BEB1, $C4E9, $BEB2, $C4F0, $BEB3, $C4F1, $BEB4, $C4F4,
        $BEB5, $C4F8, $BEB6, $C4FA, $BEB7, $C4FF, $BEB8, $C500,
        $BEB9, $C501, $BEBA, $C50C, $BEBB, $C510, $BEBC, $C514,
        $BEBD, $C51C, $BEBE, $C528, $BEBF, $C529, $BEC0, $C52C,
        $BEC1, $C530, $BEC2, $C538, $BEC3, $C539, $BEC4, $C53B,
        $BEC5, $C53D, $BEC6, $C544, $BEC7, $C545, $BEC8, $C548,
        $BEC9, $C549, $BECA, $C54A, $BECB, $C54C, $BECC, $C54D,
        $BECD, $C54E, $BECE, $C553, $BECF, $C554, $BED0, $C555,
        $BED1, $C557, $BED2, $C558, $BED3, $C559, $BED4, $C55D,
        $BED5, $C55E, $BED6, $C560, $BED7, $C561, $BED8, $C564,
        $BED9, $C568, $BEDA, $C570, $BEDB, $C571, $BEDC, $C573,
        $BEDD, $C574, $BEDE, $C575, $BEDF, $C57C, $BEE0, $C57D,
        $BEE1, $C580, $BEE2, $C584, $BEE3, $C587, $BEE4, $C58C,
        $BEE5, $C58D, $BEE6, $C58F, $BEE7, $C591, $BEE8, $C595,
        $BEE9, $C597, $BEEA, $C598, $BEEB, $C59C, $BEEC, $C5A0,
        $BEED, $C5A9, $BEEE, $C5B4, $BEEF, $C5B5, $BEF0, $C5B8,
        $BEF1, $C5B9, $BEF2, $C5BB, $BEF3, $C5BC, $BEF4, $C5BD,
        $BEF5, $C5BE, $BEF6, $C5C4, $BEF7, $C5C5, $BEF8, $C5C6,
        $BEF9, $C5C7, $BEFA, $C5C8, $BEFB, $C5C9, $BEFC, $C5CA,
        $BEFD, $C5CC, $BEFE, $C5CE, $BFA1, $C5D0, $BFA2, $C5D1,
        $BFA3, $C5D4, $BFA4, $C5D8, $BFA5, $C5E0, $BFA6, $C5E1,
        $BFA7, $C5E3, $BFA8, $C5E5, $BFA9, $C5EC, $BFAA, $C5ED,
        $BFAB, $C5EE, $BFAC, $C5F0, $BFAD, $C5F4, $BFAE, $C5F6,
        $BFAF, $C5F7, $BFB0, $C5FC, $BFB1, $C5FD, $BFB2, $C5FE,
        $BFB3, $C5FF, $BFB4, $C600, $BFB5, $C601, $BFB6, $C605,
        $BFB7, $C606, $BFB8, $C607, $BFB9, $C608, $BFBA, $C60C,
        $BFBB, $C610, $BFBC, $C618, $BFBD, $C619, $BFBE, $C61B,
        $BFBF, $C61C, $BFC0, $C624, $BFC1, $C625, $BFC2, $C628,
        $BFC3, $C62C, $BFC4, $C62D, $BFC5, $C62E, $BFC6, $C630,
        $BFC7, $C633, $BFC8, $C634, $BFC9, $C635, $BFCA, $C637,
        $BFCB, $C639, $BFCC, $C63B, $BFCD, $C640, $BFCE, $C641,
        $BFCF, $C644, $BFD0, $C648, $BFD1, $C650, $BFD2, $C651,
        $BFD3, $C653, $BFD4, $C654, $BFD5, $C655, $BFD6, $C65C,
        $BFD7, $C65D, $BFD8, $C660, $BFD9, $C66C, $BFDA, $C66F,
        $BFDB, $C671, $BFDC, $C678, $BFDD, $C679, $BFDE, $C67C,
        $BFDF, $C680, $BFE0, $C688, $BFE1, $C689, $BFE2, $C68B,
        $BFE3, $C68D, $BFE4, $C694, $BFE5, $C695, $BFE6, $C698,
        $BFE7, $C69C, $BFE8, $C6A4, $BFE9, $C6A5, $BFEA, $C6A7,
        $BFEB, $C6A9, $BFEC, $C6B0, $BFED, $C6B1, $BFEE, $C6B4,
        $BFEF, $C6B8, $BFF0, $C6B9, $BFF1, $C6BA, $BFF2, $C6C0,
        $BFF3, $C6C1, $BFF4, $C6C3, $BFF5, $C6C5, $BFF6, $C6CC,
        $BFF7, $C6CD, $BFF8, $C6D0, $BFF9, $C6D4, $BFFA, $C6DC,
        $BFFB, $C6DD, $BFFC, $C6E0, $BFFD, $C6E1, $BFFE, $C6E8,
        $C0A1, $C6E9, $C0A2, $C6EC, $C0A3, $C6F0, $C0A4, $C6F8,
        $C0A5, $C6F9, $C0A6, $C6FD, $C0A7, $C704, $C0A8, $C705,
        $C0A9, $C708, $C0AA, $C70C, $C0AB, $C714, $C0AC, $C715,
        $C0AD, $C717, $C0AE, $C719, $C0AF, $C720, $C0B0, $C721,
        $C0B1, $C724, $C0B2, $C728, $C0B3, $C730, $C0B4, $C731,
        $C0B5, $C733, $C0B6, $C735, $C0B7, $C737, $C0B8, $C73C,
        $C0B9, $C73D, $C0BA, $C740, $C0BB, $C744, $C0BC, $C74A,
        $C0BD, $C74C, $C0BE, $C74D, $C0BF, $C74F, $C0C0, $C751,
        $C0C1, $C752, $C0C2, $C753, $C0C3, $C754, $C0C4, $C755,
        $C0C5, $C756, $C0C6, $C757, $C0C7, $C758, $C0C8, $C75C,
        $C0C9, $C760, $C0CA, $C768, $C0CB, $C76B, $C0CC, $C774,
        $C0CD, $C775, $C0CE, $C778, $C0CF, $C77C, $C0D0, $C77D,
        $C0D1, $C77E, $C0D2, $C783, $C0D3, $C784, $C0D4, $C785,
        $C0D5, $C787, $C0D6, $C788, $C0D7, $C789, $C0D8, $C78A,
        $C0D9, $C78E, $C0DA, $C790, $C0DB, $C791, $C0DC, $C794,
        $C0DD, $C796, $C0DE, $C797, $C0DF, $C798, $C0E0, $C79A,
        $C0E1, $C7A0, $C0E2, $C7A1, $C0E3, $C7A3, $C0E4, $C7A4,
        $C0E5, $C7A5, $C0E6, $C7A6, $C0E7, $C7AC, $C0E8, $C7AD,
        $C0E9, $C7B0, $C0EA, $C7B4, $C0EB, $C7BC, $C0EC, $C7BD,
        $C0ED, $C7BF, $C0EE, $C7C0, $C0EF, $C7C1, $C0F0, $C7C8,
        $C0F1, $C7C9, $C0F2, $C7CC, $C0F3, $C7CE, $C0F4, $C7D0,
        $C0F5, $C7D8, $C0F6, $C7DD, $C0F7, $C7E4, $C0F8, $C7E8,
        $C0F9, $C7EC, $C0FA, $C800, $C0FB, $C801, $C0FC, $C804,
        $C0FD, $C808, $C0FE, $C80A, $C1A1, $C810, $C1A2, $C811,
        $C1A3, $C813, $C1A4, $C815, $C1A5, $C816, $C1A6, $C81C,
        $C1A7, $C81D, $C1A8, $C820, $C1A9, $C824, $C1AA, $C82C,
        $C1AB, $C82D, $C1AC, $C82F, $C1AD, $C831, $C1AE, $C838,
        $C1AF, $C83C, $C1B0, $C840, $C1B1, $C848, $C1B2, $C849,
        $C1B3, $C84C, $C1B4, $C84D, $C1B5, $C854, $C1B6, $C870,
        $C1B7, $C871, $C1B8, $C874, $C1B9, $C878, $C1BA, $C87A,
        $C1BB, $C880, $C1BC, $C881, $C1BD, $C883, $C1BE, $C885,
        $C1BF, $C886, $C1C0, $C887, $C1C1, $C88B, $C1C2, $C88C,
        $C1C3, $C88D, $C1C4, $C894, $C1C5, $C89D, $C1C6, $C89F,
        $C1C7, $C8A1, $C1C8, $C8A8, $C1C9, $C8BC, $C1CA, $C8BD,
        $C1CB, $C8C4, $C1CC, $C8C8, $C1CD, $C8CC, $C1CE, $C8D4,
        $C1CF, $C8D5, $C1D0, $C8D7, $C1D1, $C8D9, $C1D2, $C8E0,
        $C1D3, $C8E1, $C1D4, $C8E4, $C1D5, $C8F5, $C1D6, $C8FC,
        $C1D7, $C8FD, $C1D8, $C900, $C1D9, $C904, $C1DA, $C905,
        $C1DB, $C906, $C1DC, $C90C, $C1DD, $C90D, $C1DE, $C90F,
        $C1DF, $C911, $C1E0, $C918, $C1E1, $C92C, $C1E2, $C934,
        $C1E3, $C950, $C1E4, $C951, $C1E5, $C954, $C1E6, $C958,
        $C1E7, $C960, $C1E8, $C961, $C1E9, $C963, $C1EA, $C96C,
        $C1EB, $C970, $C1EC, $C974, $C1ED, $C97C, $C1EE, $C988,
        $C1EF, $C989, $C1F0, $C98C, $C1F1, $C990, $C1F2, $C998,
        $C1F3, $C999, $C1F4, $C99B, $C1F5, $C99D, $C1F6, $C9C0,
        $C1F7, $C9C1, $C1F8, $C9C4, $C1F9, $C9C7, $C1FA, $C9C8,
        $C1FB, $C9CA, $C1FC, $C9D0, $C1FD, $C9D1, $C1FE, $C9D3,
        $C2A1, $C9D5, $C2A2, $C9D6, $C2A3, $C9D9, $C2A4, $C9DA,
        $C2A5, $C9DC, $C2A6, $C9DD, $C2A7, $C9E0, $C2A8, $C9E2,
        $C2A9, $C9E4, $C2AA, $C9E7, $C2AB, $C9EC, $C2AC, $C9ED,
        $C2AD, $C9EF, $C2AE, $C9F0, $C2AF, $C9F1, $C2B0, $C9F8,
        $C2B1, $C9F9, $C2B2, $C9FC, $C2B3, $CA00, $C2B4, $CA08,
        $C2B5, $CA09, $C2B6, $CA0B, $C2B7, $CA0C, $C2B8, $CA0D,
        $C2B9, $CA14, $C2BA, $CA18, $C2BB, $CA29, $C2BC, $CA4C,
        $C2BD, $CA4D, $C2BE, $CA50, $C2BF, $CA54, $C2C0, $CA5C,
        $C2C1, $CA5D, $C2C2, $CA5F, $C2C3, $CA60, $C2C4, $CA61,
        $C2C5, $CA68, $C2C6, $CA7D, $C2C7, $CA84, $C2C8, $CA98,
        $C2C9, $CABC, $C2CA, $CABD, $C2CB, $CAC0, $C2CC, $CAC4,
        $C2CD, $CACC, $C2CE, $CACD, $C2CF, $CACF, $C2D0, $CAD1,
        $C2D1, $CAD3, $C2D2, $CAD8, $C2D3, $CAD9, $C2D4, $CAE0,
        $C2D5, $CAEC, $C2D6, $CAF4, $C2D7, $CB08, $C2D8, $CB10,
        $C2D9, $CB14, $C2DA, $CB18, $C2DB, $CB20, $C2DC, $CB21,
        $C2DD, $CB41, $C2DE, $CB48, $C2DF, $CB49, $C2E0, $CB4C,
        $C2E1, $CB50, $C2E2, $CB58, $C2E3, $CB59, $C2E4, $CB5D,
        $C2E5, $CB64, $C2E6, $CB78, $C2E7, $CB79, $C2E8, $CB9C,
        $C2E9, $CBB8, $C2EA, $CBD4, $C2EB, $CBE4, $C2EC, $CBE7,
        $C2ED, $CBE9, $C2EE, $CC0C, $C2EF, $CC0D, $C2F0, $CC10,
        $C2F1, $CC14, $C2F2, $CC1C, $C2F3, $CC1D, $C2F4, $CC21,
        $C2F5, $CC22, $C2F6, $CC27, $C2F7, $CC28, $C2F8, $CC29,
        $C2F9, $CC2C, $C2FA, $CC2E, $C2FB, $CC30, $C2FC, $CC38,
        $C2FD, $CC39, $C2FE, $CC3B, $C3A1, $CC3C, $C3A2, $CC3D,
        $C3A3, $CC3E, $C3A4, $CC44, $C3A5, $CC45, $C3A6, $CC48,
        $C3A7, $CC4C, $C3A8, $CC54, $C3A9, $CC55, $C3AA, $CC57,
        $C3AB, $CC58, $C3AC, $CC59, $C3AD, $CC60, $C3AE, $CC64,
        $C3AF, $CC66, $C3B0, $CC68, $C3B1, $CC70, $C3B2, $CC75,
        $C3B3, $CC98, $C3B4, $CC99, $C3B5, $CC9C, $C3B6, $CCA0,
        $C3B7, $CCA8, $C3B8, $CCA9, $C3B9, $CCAB, $C3BA, $CCAC,
        $C3BB, $CCAD, $C3BC, $CCB4, $C3BD, $CCB5, $C3BE, $CCB8,
        $C3BF, $CCBC, $C3C0, $CCC4, $C3C1, $CCC5, $C3C2, $CCC7,
        $C3C3, $CCC9, $C3C4, $CCD0, $C3C5, $CCD4, $C3C6, $CCE4,
        $C3C7, $CCEC, $C3C8, $CCF0, $C3C9, $CD01, $C3CA, $CD08,
        $C3CB, $CD09, $C3CC, $CD0C, $C3CD, $CD10, $C3CE, $CD18,
        $C3CF, $CD19, $C3D0, $CD1B, $C3D1, $CD1D, $C3D2, $CD24,
        $C3D3, $CD28, $C3D4, $CD2C, $C3D5, $CD39, $C3D6, $CD5C,
        $C3D7, $CD60, $C3D8, $CD64, $C3D9, $CD6C, $C3DA, $CD6D,
        $C3DB, $CD6F, $C3DC, $CD71, $C3DD, $CD78, $C3DE, $CD88,
        $C3DF, $CD94, $C3E0, $CD95, $C3E1, $CD98, $C3E2, $CD9C,
        $C3E3, $CDA4, $C3E4, $CDA5, $C3E5, $CDA7, $C3E6, $CDA9,
        $C3E7, $CDB0, $C3E8, $CDC4, $C3E9, $CDCC, $C3EA, $CDD0,
        $C3EB, $CDE8, $C3EC, $CDEC, $C3ED, $CDF0, $C3EE, $CDF8,
        $C3EF, $CDF9, $C3F0, $CDFB, $C3F1, $CDFD, $C3F2, $CE04,
        $C3F3, $CE08, $C3F4, $CE0C, $C3F5, $CE14, $C3F6, $CE19,
        $C3F7, $CE20, $C3F8, $CE21, $C3F9, $CE24, $C3FA, $CE28,
        $C3FB, $CE30, $C3FC, $CE31, $C3FD, $CE33, $C3FE, $CE35,
        $C4A1, $CE58, $C4A2, $CE59, $C4A3, $CE5C, $C4A4, $CE5F,
        $C4A5, $CE60, $C4A6, $CE61, $C4A7, $CE68, $C4A8, $CE69,
        $C4A9, $CE6B, $C4AA, $CE6D, $C4AB, $CE74, $C4AC, $CE75,
        $C4AD, $CE78, $C4AE, $CE7C, $C4AF, $CE84, $C4B0, $CE85,
        $C4B1, $CE87, $C4B2, $CE89, $C4B3, $CE90, $C4B4, $CE91,
        $C4B5, $CE94, $C4B6, $CE98, $C4B7, $CEA0, $C4B8, $CEA1,
        $C4B9, $CEA3, $C4BA, $CEA4, $C4BB, $CEA5, $C4BC, $CEAC,
        $C4BD, $CEAD, $C4BE, $CEC1, $C4BF, $CEE4, $C4C0, $CEE5,
        $C4C1, $CEE8, $C4C2, $CEEB, $C4C3, $CEEC, $C4C4, $CEF4,
        $C4C5, $CEF5, $C4C6, $CEF7, $C4C7, $CEF8, $C4C8, $CEF9,
        $C4C9, $CF00, $C4CA, $CF01, $C4CB, $CF04, $C4CC, $CF08,
        $C4CD, $CF10, $C4CE, $CF11, $C4CF, $CF13, $C4D0, $CF15,
        $C4D1, $CF1C, $C4D2, $CF20, $C4D3, $CF24, $C4D4, $CF2C,
        $C4D5, $CF2D, $C4D6, $CF2F, $C4D7, $CF30, $C4D8, $CF31,
        $C4D9, $CF38, $C4DA, $CF54, $C4DB, $CF55, $C4DC, $CF58,
        $C4DD, $CF5C, $C4DE, $CF64, $C4DF, $CF65, $C4E0, $CF67,
        $C4E1, $CF69, $C4E2, $CF70, $C4E3, $CF71, $C4E4, $CF74,
        $C4E5, $CF78, $C4E6, $CF80, $C4E7, $CF85, $C4E8, $CF8C,
        $C4E9, $CFA1, $C4EA, $CFA8, $C4EB, $CFB0, $C4EC, $CFC4,
        $C4ED, $CFE0, $C4EE, $CFE1, $C4EF, $CFE4, $C4F0, $CFE8,
        $C4F1, $CFF0, $C4F2, $CFF1, $C4F3, $CFF3, $C4F4, $CFF5,
        $C4F5, $CFFC, $C4F6, $D000, $C4F7, $D004, $C4F8, $D011,
        $C4F9, $D018, $C4FA, $D02D, $C4FB, $D034, $C4FC, $D035,
        $C4FD, $D038, $C4FE, $D03C, $C5A1, $D044, $C5A2, $D045,
        $C5A3, $D047, $C5A4, $D049, $C5A5, $D050, $C5A6, $D054,
        $C5A7, $D058, $C5A8, $D060, $C5A9, $D06C, $C5AA, $D06D,
        $C5AB, $D070, $C5AC, $D074, $C5AD, $D07C, $C5AE, $D07D,
        $C5AF, $D081, $C5B0, $D0A4, $C5B1, $D0A5, $C5B2, $D0A8,
        $C5B3, $D0AC, $C5B4, $D0B4, $C5B5, $D0B5, $C5B6, $D0B7,
        $C5B7, $D0B9, $C5B8, $D0C0, $C5B9, $D0C1, $C5BA, $D0C4,
        $C5BB, $D0C8, $C5BC, $D0C9, $C5BD, $D0D0, $C5BE, $D0D1,
        $C5BF, $D0D3, $C5C0, $D0D4, $C5C1, $D0D5, $C5C2, $D0DC,
        $C5C3, $D0DD, $C5C4, $D0E0, $C5C5, $D0E4, $C5C6, $D0EC,
        $C5C7, $D0ED, $C5C8, $D0EF, $C5C9, $D0F0, $C5CA, $D0F1,
        $C5CB, $D0F8, $C5CC, $D10D, $C5CD, $D130, $C5CE, $D131,
        $C5CF, $D134, $C5D0, $D138, $C5D1, $D13A, $C5D2, $D140,
        $C5D3, $D141, $C5D4, $D143, $C5D5, $D144, $C5D6, $D145,
        $C5D7, $D14C, $C5D8, $D14D, $C5D9, $D150, $C5DA, $D154,
        $C5DB, $D15C, $C5DC, $D15D, $C5DD, $D15F, $C5DE, $D161,
        $C5DF, $D168, $C5E0, $D16C, $C5E1, $D17C, $C5E2, $D184,
        $C5E3, $D188, $C5E4, $D1A0, $C5E5, $D1A1, $C5E6, $D1A4,
        $C5E7, $D1A8, $C5E8, $D1B0, $C5E9, $D1B1, $C5EA, $D1B3,
        $C5EB, $D1B5, $C5EC, $D1BA, $C5ED, $D1BC, $C5EE, $D1C0,
        $C5EF, $D1D8, $C5F0, $D1F4, $C5F1, $D1F8, $C5F2, $D207,
        $C5F3, $D209, $C5F4, $D210, $C5F5, $D22C, $C5F6, $D22D,
        $C5F7, $D230, $C5F8, $D234, $C5F9, $D23C, $C5FA, $D23D,
        $C5FB, $D23F, $C5FC, $D241, $C5FD, $D248, $C5FE, $D25C,
        $C6A1, $D264, $C6A2, $D280, $C6A3, $D281, $C6A4, $D284,
        $C6A5, $D288, $C6A6, $D290, $C6A7, $D291, $C6A8, $D295,
        $C6A9, $D29C, $C6AA, $D2A0, $C6AB, $D2A4, $C6AC, $D2AC,
        $C6AD, $D2B1, $C6AE, $D2B8, $C6AF, $D2B9, $C6B0, $D2BC,
        $C6B1, $D2BF, $C6B2, $D2C0, $C6B3, $D2C2, $C6B4, $D2C8,
        $C6B5, $D2C9, $C6B6, $D2CB, $C6B7, $D2D4, $C6B8, $D2D8,
        $C6B9, $D2DC, $C6BA, $D2E4, $C6BB, $D2E5, $C6BC, $D2F0,
        $C6BD, $D2F1, $C6BE, $D2F4, $C6BF, $D2F8, $C6C0, $D300,
        $C6C1, $D301, $C6C2, $D303, $C6C3, $D305, $C6C4, $D30C,
        $C6C5, $D30D, $C6C6, $D30E, $C6C7, $D310, $C6C8, $D314,
        $C6C9, $D316, $C6CA, $D31C, $C6CB, $D31D, $C6CC, $D31F,
        $C6CD, $D320, $C6CE, $D321, $C6CF, $D325, $C6D0, $D328,
        $C6D1, $D329, $C6D2, $D32C, $C6D3, $D330, $C6D4, $D338,
        $C6D5, $D339, $C6D6, $D33B, $C6D7, $D33C, $C6D8, $D33D,
        $C6D9, $D344, $C6DA, $D345, $C6DB, $D37C, $C6DC, $D37D,
        $C6DD, $D380, $C6DE, $D384, $C6DF, $D38C, $C6E0, $D38D,
        $C6E1, $D38F, $C6E2, $D390, $C6E3, $D391, $C6E4, $D398,
        $C6E5, $D399, $C6E6, $D39C, $C6E7, $D3A0, $C6E8, $D3A8,
        $C6E9, $D3A9, $C6EA, $D3AB, $C6EB, $D3AD, $C6EC, $D3B4,
        $C6ED, $D3B8, $C6EE, $D3BC, $C6EF, $D3C4, $C6F0, $D3C5,
        $C6F1, $D3C8, $C6F2, $D3C9, $C6F3, $D3D0, $C6F4, $D3D8,
        $C6F5, $D3E1, $C6F6, $D3E3, $C6F7, $D3EC, $C6F8, $D3ED,
        $C6F9, $D3F0, $C6FA, $D3F4, $C6FB, $D3FC, $C6FC, $D3FD,
        $C6FD, $D3FF, $C6FE, $D401, $C7A1, $D408, $C7A2, $D41D,
        $C7A3, $D440, $C7A4, $D444, $C7A5, $D45C, $C7A6, $D460,
        $C7A7, $D464, $C7A8, $D46D, $C7A9, $D46F, $C7AA, $D478,
        $C7AB, $D479, $C7AC, $D47C, $C7AD, $D47F, $C7AE, $D480,
        $C7AF, $D482, $C7B0, $D488, $C7B1, $D489, $C7B2, $D48B,
        $C7B3, $D48D, $C7B4, $D494, $C7B5, $D4A9, $C7B6, $D4CC,
        $C7B7, $D4D0, $C7B8, $D4D4, $C7B9, $D4DC, $C7BA, $D4DF,
        $C7BB, $D4E8, $C7BC, $D4EC, $C7BD, $D4F0, $C7BE, $D4F8,
        $C7BF, $D4FB, $C7C0, $D4FD, $C7C1, $D504, $C7C2, $D508,
        $C7C3, $D50C, $C7C4, $D514, $C7C5, $D515, $C7C6, $D517,
        $C7C7, $D53C, $C7C8, $D53D, $C7C9, $D540, $C7CA, $D544,
        $C7CB, $D54C, $C7CC, $D54D, $C7CD, $D54F, $C7CE, $D551,
        $C7CF, $D558, $C7D0, $D559, $C7D1, $D55C, $C7D2, $D560,
        $C7D3, $D565, $C7D4, $D568, $C7D5, $D569, $C7D6, $D56B,
        $C7D7, $D56D, $C7D8, $D574, $C7D9, $D575, $C7DA, $D578,
        $C7DB, $D57C, $C7DC, $D584, $C7DD, $D585, $C7DE, $D587,
        $C7DF, $D588, $C7E0, $D589, $C7E1, $D590, $C7E2, $D5A5,
        $C7E3, $D5C8, $C7E4, $D5C9, $C7E5, $D5CC, $C7E6, $D5D0,
        $C7E7, $D5D2, $C7E8, $D5D8, $C7E9, $D5D9, $C7EA, $D5DB,
        $C7EB, $D5DD, $C7EC, $D5E4, $C7ED, $D5E5, $C7EE, $D5E8,
        $C7EF, $D5EC, $C7F0, $D5F4, $C7F1, $D5F5, $C7F2, $D5F7,
        $C7F3, $D5F9, $C7F4, $D600, $C7F5, $D601, $C7F6, $D604,
        $C7F7, $D608, $C7F8, $D610, $C7F9, $D611, $C7FA, $D613,
        $C7FB, $D614, $C7FC, $D615, $C7FD, $D61C, $C7FE, $D620,
        $C8A1, $D624, $C8A2, $D62D, $C8A3, $D638, $C8A4, $D639,
        $C8A5, $D63C, $C8A6, $D640, $C8A7, $D645, $C8A8, $D648,
        $C8A9, $D649, $C8AA, $D64B, $C8AB, $D64D, $C8AC, $D651,
        $C8AD, $D654, $C8AE, $D655, $C8AF, $D658, $C8B0, $D65C,
        $C8B1, $D667, $C8B2, $D669, $C8B3, $D670, $C8B4, $D671,
        $C8B5, $D674, $C8B6, $D683, $C8B7, $D685, $C8B8, $D68C,
        $C8B9, $D68D, $C8BA, $D690, $C8BB, $D694, $C8BC, $D69D,
        $C8BD, $D69F, $C8BE, $D6A1, $C8BF, $D6A8, $C8C0, $D6AC,
        $C8C1, $D6B0, $C8C2, $D6B9, $C8C3, $D6BB, $C8C4, $D6C4,
        $C8C5, $D6C5, $C8C6, $D6C8, $C8C7, $D6CC, $C8C8, $D6D1,
        $C8C9, $D6D4, $C8CA, $D6D7, $C8CB, $D6D9, $C8CC, $D6E0,
        $C8CD, $D6E4, $C8CE, $D6E8, $C8CF, $D6F0, $C8D0, $D6F5,
        $C8D1, $D6FC, $C8D2, $D6FD, $C8D3, $D700, $C8D4, $D704,
        $C8D5, $D711, $C8D6, $D718, $C8D7, $D719, $C8D8, $D71C,
        $C8D9, $D720, $C8DA, $D728, $C8DB, $D729, $C8DC, $D72B,
        $C8DD, $D72D, $C8DE, $D734, $C8DF, $D735, $C8E0, $D738,
        $C8E1, $D73C, $C8E2, $D744, $C8E3, $D747, $C8E4, $D749,
        $C8E5, $D750, $C8E6, $D751, $C8E7, $D754, $C8E8, $D756,
        $C8E9, $D757, $C8EA, $D758, $C8EB, $D759, $C8EC, $D760,
        $C8ED, $D761, $C8EE, $D763, $C8EF, $D765, $C8F0, $D769,
        $C8F1, $D76C, $C8F2, $D770, $C8F3, $D774, $C8F4, $D77C,
        $C8F5, $D77D, $C8F6, $D781, $C8F7, $D788, $C8F8, $D789,
        $C8F9, $D78C, $C8FA, $D790, $C8FB, $D798, $C8FC, $D799,
        $C8FD, $D79B, $C8FE, $D79D
    );

    page00 : TCodeArray =
    (
        $00, $01, $02, $03, $04, $05, $06, $07, (* $00-$07 *)
        $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, (* $08-$0F *)
        $10, $11, $12, $13, $14, $15, $16, $17, (* $10-$17 *)
        $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, (* $18-$1F *)
        $20, $21, $22, $23, $24, $25, $26, $27, (* $20-$27 *)
        $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, (* $28-$2F *)
        $30, $31, $32, $33, $34, $35, $36, $37, (* $30-$37 *)
        $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, (* $38-$3F *)
        $40, $41, $42, $43, $44, $45, $46, $47, (* $40-$47 *)
        $48, $49, $4A, $4B, $4C, $4D, $4E, $4F, (* $48-$4F *)
        $50, $51, $52, $53, $54, $55, $56, $57, (* $50-$57 *)
        $58, $59, $5A, $5B, $5C, $5D, $5E, $5F, (* $58-$5F *)
        $60, $61, $62, $63, $64, $65, $66, $67, (* $60-$67 *)
        $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, (* $68-$6F *)
        $70, $71, $72, $73, $74, $75, $76, $77, (* $70-$77 *)
        $78, $79, $7A, $7B, $7C, $7D, $7E, $7F, (* $78-$7F *)

        $00, $00, $00, $00, $00, $00, $00, $00, (* $80-$87 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $88-$8F *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $90-$97 *)
        $00, $00, $00, $00, $00, $00, $00, $92, (* $98-$9F *)
        $FF, $AD, $BD, $9C, $CF, $BE, $DD, $F5, (* $A0-$A7 *)
        $F9, $B8, $00, $AE, $AA, $F0, $00, $EE, (* $A8-$AF *)
        $F8, $F1, $FD, $FC, $EF, $E6, $F4, $FA, (* $B0-$B7 *)
        $F7, $FB, $00, $AF, $AC, $AB, $F3, $00, (* $B8-$BF *)
        $B7, $B5, $B6, $C7, $8E, $8F, $92, $80, (* $C0-$C7 *)
        $D4, $90, $D2, $D3, $DE, $D6, $D7, $D8, (* $C8-$CF *)
        $00, $A5, $E3, $E0, $E2, $E5, $99, $9E, (* $D0-$D7 *)
        $9D, $EB, $E9, $EA, $9A, $ED, $E8, $E1, (* $D8-$DF *)
        $A1, $A0, $83, $C6, $84, $86, $91, $87, (* $E0-$E7 *)
        $8A, $82, $88, $89, $8D, $00, $8C, $8B, (* $E8-$EF *)
        $D0, $A4, $95, $A2, $93, $E4, $94, $F6, (* $F0-$F7 *)
        $9B, $97, $A3, $96, $81, $EC, $E7, $98  (* $F8-$FF *)
    );

    page25 : TCodeArray =
    (
        $C4, $00, $B3, $00, $00, $00, $00, $00, (* $00-$07 *)
        $00, $00, $00, $00, $DA, $00, $00, $00, (* $08-$0F *)
        $BF, $00, $00, $00, $C0, $00, $00, $00, (* $10-$17 *)
        $D9, $00, $00, $00, $C3, $00, $00, $00, (* $18-$1F *)
        $00, $00, $00, $00, $B4, $00, $00, $00, (* $20-$27 *)
        $00, $00, $00, $00, $C2, $00, $00, $00, (* $28-$2F *)
        $00, $00, $00, $00, $C1, $00, $00, $00, (* $30-$37 *)
        $00, $00, $00, $00, $C5, $00, $00, $00, (* $38-$3F *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $40-$47 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $48-$4F *)
        $CD, $BA, $00, $00, $C9, $00, $00, $BB, (* $50-$57 *)
        $00, $00, $C8, $00, $00, $BC, $00, $00, (* $58-$5F *)
        $CC, $00, $00, $B9, $00, $00, $CB, $00, (* $60-$67 *)
        $00, $CA, $00, $00, $CE, $00, $00, $00, (* $68-$6F *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $70-$77 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $78-$7F *)

        $DF, $00, $00, $00, $DC, $00, $00, $00, (* $80-$87 *)
        $DB, $00, $00, $00, $00, $00, $00, $00, (* $88-$8F *)
        $00, $B0, $B1, $B2, $00, $00, $00, $00, (* $90-$97 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $98-$9F *)
        $FE, $00, $00, $00, $00, $00, $00, $00, (* $A0-$A7 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $A8-$AF *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $B0-$B7 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $B8-$BF *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $C0-$C7 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $C8-$CF *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $D0-$D7 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $D8-$DF *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $E0-$E7 *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $E8-$EF *)
        $00, $00, $00, $00, $00, $00, $00, $00, (* $F0-$F7 *)
        $00, $00, $00, $00, $00, $00, $00, $00  (* $F8-$FF *)
    );

    fatUni2ascPg : array [ 0..255 ] of PCodeArray =
    (
        @page00, nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, @page25, nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil,
        nil,     nil, nil, nil, nil,     nil, nil, nil
    );

(*
    Translate a string, including coded sequences into Unicode

    from namei.c of vfat-os2 v0.004
*)
function asc2uni( const s : string ) : string;
var
    i       : Integer;
    ni      : Integer;
    c1      : Byte;
    c2      : Byte;
    c3      : Byte;
    uc, ks  : Word;
    middle  : Word;
    left    : Word;
    right   : Word;

begin
    result := '';
    if Length( s ) > 127 then
        Exit;

    i := 0;
    ni := 1;
    while i < Length( s ) do
    begin
        c1 := fatCode2uni[ Ord( s[ ni + 1 ])];
        c2 := fatCode2uni[ Ord( s[ ni + 2 ])];
        c3 := fatCode2uni[ Ord( s[ ni + 3 ])];

        if ( i < ( Length( s ) - 4 )) and ( s[ ni ] = ':' ) and
           ( c1 <> 255 ) and ( c2 <> 255 ) and ( c2 <> 255 ) then
        begin
            result := result + Chr(( c1 shl 4 ) + ( c2 shr 2 ));
            result := result + Chr((( c2 and $03 ) shl 6 ) + c3 );
            Inc( ni, 4 );
        end
        else
        begin   (* 한글인가? *)
            if ( i < Length( s ) - 1 ) and ( s[ ni ] > #$80 ) and
               ( s[ ni + 1 ] > #$80 ) then
            begin
                ks := ( Ord( s[ ni ] ) shl 8 ) + Ord( s[ ni + 1 ]);
                uc := 0;

                if ( ks >= $A4A1 ) and ( ks <= $A4FE ) then
                    uc := ( ks - $7370 )    (* 한글 자모 *)
                else if ( ks >= $B0A1 ) and ( ks <= $C8FE ) then
                begin
                    left := 0;
                    right := 2349;  (* 완성형글자수=2350 *)

                    while left <= right do
                    begin
                        middle := ( left + right ) div 2;
                        if fatHK2U[ middle * 2 ] < ks then
                            left := middle + 1
                        else if fatHK2U[ middle * 2 ] = ks then
                        begin
                            uc := fatHK2U[ middle * 2 + 1 ];
                            break;
                        end
                        else
                            right := middle - 1;
                    end;
                end;

                if uc = 0 then
                begin
                    result := result + Chr( fatAsc2uni[ Ord( s[ ni ])].uni1 );
                    result := result + Chr( fatAsc2uni[ Ord( s[ ni ])].uni2 );
                    Inc( ni );
                end
                else
                begin
                    result := result + Chr( uc and $FF );
                    result := result + Chr( uc shr 8 );
                    Inc( ni, 2 );
                    Inc( i );
                end;
            end
            else
            begin
                result := result + Chr( fatAsc2uni[ Ord( s[ ni ])].uni1 );
                result := result + Chr( fatAsc2uni[ Ord( s[ ni ])].uni2 );
                Inc( ni );
            end;
        end;

        Inc( i );
    end;

    if ( Length( result ) mod 26 ) <> 0 then
    begin
        result := result + #0;
        result := result + #0;

        while ( Length( result ) mod 26 ) <> 0 do
        begin
            result := result + #$FF;
            result := result + #$FF;
        end;
    end;
end;

(*
    Convert Unicode string to ASCII.  If uni_xlate is enabled and we
    can't get a 1:1 conversion, use a colon as an escape character since
    it is normally invalid on the vfat filesystem.  The following three
    characters are a sort of uuencoded 16 bit Unicode value.  This lets
    us do a full dump and restore of Unicode filenames.  We could get
    into some trouble with long Unicode names, but ignore that right now.

    from dir.c of vfat-os2 v0.004
*)
function uni2asc( const s : string ) : string;
var
    page, pgOff     : Integer;
    value           : Integer;
    i, j            : Integer;
    uniPage         : PCodeArray;
    uc, ks          : Word;
    middle          : Word;
    left            : Word;
    right           : Word;

begin
    result := '';
    i := 1;
    while i <= Length( s ) do
    begin
        pgOff := Ord( s[ i ]);
        Inc( i );

        page := Ord( s[ i ]);
        Inc( i );

        uniPage := fatUni2ascPg[ page ];
        if ( uniPage <> nil ) and ( uniPage^[ pgOff ] <> 0 ) then
            result := result + Chr( uniPage^[ pgOff ])
        else
        begin
            uc := ( page shl 8 ) + pgOff;
            ks := 0;

            if ( uc >= $3131 ) and ( uc <= $318E ) then
                ks := uc + $7370    (* 한글 자모 *)
            else if ( uc >= $AC00 ) and ( uc <= $D7AF ) then
            begin
                left := 0;
                right := 2349;      (* 완성형글자수=2350 *)

                while left <= right do
                begin
                    middle := ( left + right ) div 2;
                    if fatHK2U[ middle * 2 + 1 ] < uc then
                        left := middle + 1
                    else if fatHK2U[ middle * 2 + 1 ] = uc then
                    begin
                        ks := fatHK2U[ middle * 2 ];
                        break;
                    end
                    else
                        right := middle - 1;
                end;
            end;

            if ks = 0 then
            begin
                result := result + ':';
                j := Length( result ) + 1;

                value := ( pgOff shl 8 ) + page;
                result[ j + 2 ] := fatUni2code[ value and $3F ];

                value := value shr 6;
                result[ j + 1 ] := fatUni2code[ value and $3F ];

                value := value shr 6;
                result[ j ] := fatUni2code[ value and $3F ];

                result[ 0 ] := Chr( j + 2 );
            end
            else
            begin
                result := result + Chr( ks shr 8 );
                result := result + chr( ks and $FF );
            end;
        end;
    end;
end;

(*
    added by KO Myung-Hun from 1999.06.20

    below, VFAT... functions and many constants were
    referenced from 'namei.c' of vfat-os2 v0.004 sources.
*)

const
    (* MS-DOS "device special files" *)
    ReservedNames : array [ 1..12 ] of string[ 4 ] =
    (
        'CON',  'PRN',  'NUL',  'AUX',
        'LPT1', 'LPT2', 'LPT3', 'LPT4',
        'COM1', 'COM2', 'COM3', 'COM4'
    );

    (* Characters that are undesirable in an MS-DOS file name *)
    badChars        : set of Char = [ '*', '?', '<', '>', '|', '\', '"', ':', '/' ];
    badIfStrict     : set of Char = [ '+', '=', ',', ';', ' ', '[', ']' ];
    replaceChars    : set of Char = [ '[', ']', ';', ',', '+', '=' ];

    skipChars : set of Char = [ '.', ':', '\', '"', '?', '<', '>', '|', ' ' ];

function VFATValidLongName( const LongName : string ) : Boolean;
var
    I   : Integer;

begin
    if ( LongName = '.' ) or ( LongName = '..' ) then
    begin
        VFATValidLongName := True;
        Exit;
    end;

    for I := 1 to Length( LongName ) do
    begin
        if LongName[ I ] in BadChars then
        begin
            VFATValidLongName := False;
            Exit;
        end;
    end;

    if ( Length( LongName ) = 3 ) or ( Length( LongName ) = 4 ) then
    begin
        I := 1;
        while I <= 12 do
        begin
            if LongName = ReservedNames[ I ] then
            begin
                VFATValidLongName := False;
                Exit;
            end;

            Inc( I );
        end;
    end;

    VFATValidLongName := True;
end;

(*
    Takes a short filename and converts it to a formatted MS-DOS filename.
    If the short filename is not a valid MS-DOS filename, an error is
    returned.  The formatted short filename is returned in 'res'.
*)
function VFATFormatName( conv : Char; const name : string; len : Integer;
    var res : string ) : Boolean;
var
    walk        : Integer;
    c           : Char;
    space       : Boolean;
    i           : Integer;

begin
    VFATFormatName := False;
    if ( name = '.' ) or ( name = '..' ) then
    begin
        res := '';
        Exit;
    end;

    space := True; (* disallow names starting with a dot *)
    c := #0;
    walk := 1;
    i := 1;
    while ( len > 0 ) and ( walk <= 8 ) do
    begin
        c := name[ i ];
        Inc( i );
        Dec( len );

        if ( conv <> 'r' ) and ( c in badChars ) then
            Exit;

        if ( conv = 's' ) and ( c in badIfStrict ) then
            Exit;

        if ( c >= 'A' ) and ( c <= 'Z' ) and ( conv in [ 's', 'x' ] ) then
            Exit;

        if ( c < ' ' ) or ( c in [ ':', '\' ]) then
            Exit;

        if c = '.' then
            break;

        space := c = ' ';

        res[ walk ] := UpCase( c );
        Inc( walk );
    end;

    if space then
        Exit;

    if ( conv in [ 's', 'x' ] ) and ( len > 0 ) and ( c <> '.' ) then
    begin
        c := name[ i ];
        Inc( i );

        Dec( len );

        if c <> '.' then
            Exit;
    end;

    while ( c <> '.' ) and ( len > 0 ) do
    begin
        c := name[ i ];
        Inc( i );

        Dec( len );
    end;

    if c = '.' then
    begin
        while walk <= 8 do
        begin
            res[ walk ] := ' ';
            Inc( walk );
        end;

        while ( len > 0 ) and ( walk <= 11 ) do
        begin
            c := name[ i ];
            Inc( i );
            Dec( len );

            if ( conv <> 'r' ) and ( c in badChars ) then
                Exit;

            if ( conv = 's' ) and ( c in badIfStrict ) then
                Exit;

            if ( conv = 'x' ) and ( c in replaceChars ) then
                Exit;

            if ( c >= 'A' ) and ( c <= 'Z' ) and ( conv in [ 's', 'x' ] ) then
                Exit;

            if ( c < ' ' ) or ( c in [ ':', '\', '.' ]) then
                Exit;

            space := c = ' ';

            res[ walk ] := UpCase( c );
            Inc( walk );
        end;

        if space then
            Exit;

        if ( conv in [ 's', 'x' ]) and ( len > 0 ) then
            Exit;
    end;

    while walk <= 11 do
    begin
        res[ walk ] := ' ';
        Inc( walk );
    end;

    res[ 0 ] := #11;

    for i := 1 to 12 do
    begin
        if Copy( res, 1, 4 ) = reservedNames[ i ] then
            Exit;
    end;

    VFATFormatName := True;
end;

function VFATCreateShortName( const dir, name : string ) : string;
var
    sz          : Integer;
    extLen      : Integer;
    baseLen     : Integer;
    totLen      : Integer;
    msdosName   : string[ 12 ];
    base        : string[ 8 ];
    ext         : string[ 3 ];
    i           : Longint;
    j           : Integer;
    res         : Boolean;
    spaces      : Integer;
    buf         : string[ 7 ];
    nameStart   : Integer;
    extStart    : Integer;

begin
    result := '';

    SZ :=0;

    if isShortName( name ) then
    begin
(*
        msdosName := LCase( name );
        if VFATFormatName( 'x', msdosName, Length( name ), result ) then
        begin
            if FileExist( FNMerge( dir, msdosName )) then
                result := '';

            Exit;
        end;
*)
        result := UCase( name );
        if FileExist( fnMerge( dir, name )) then
            result := '';
        Exit;
    end;

    (* Now, we need to create a shortname from the long name *)
    extStart := PosR( '.', name );
    if ( extStart = 0 ) or ( extStart = Length( name )) then
    begin
        sz := Length( name );
        extStart := 0;
    end
    else
    begin
        (*
            Names which start with a dot could be just
            an extension eg. "...test".  In this case Win95
            uses the extension as the name and sets no extension.
        *)

        for nameStart := 1 to extStart - 1 do
        begin
            if not ( name[ nameStart ] in skipChars ) then
                break;
        end;

        if nameStart <> extStart then
        begin
            sz := extStart - 1;
            Inc( extStart );
        end
        else
        begin
            sz := Length( name );
            extStart := 0;
        end;
    end;

    baseLen := 0;
    i := 1;

    while ( i <= sz ) and ( baseLen < 8 ) do
    begin
        if not ( name[ i ] in skipChars ) then
        begin
            Inc( baseLen );
            base[ baseLen ] := LowCase( name[ i ]);

            if base[ baseLen ] in replaceChars then
                base[ baseLen ] := '_';
        end;

        Inc( i );
    end;

    if baseLen = 0 then
        Exit;

    spaces := 8 - baseLen;
    extLen := 0;

    if extStart > 0 then
    begin
        i := extStart;
        while ( extLen < 3 ) and ( i <= Length( name )) do
        begin
            if not ( name[ i ] in skipChars ) then
            begin
                Inc( extLen );
                ext[ extLen ] := LowCase( name[ i ]);
                if ext[ extLen ] in replaceChars then
                    ext[ extLen ] := '_';
            end;

            Inc( i );
        end;
    end;

    i := 1;
    res := False;
    while i <= baseLen do
    begin
        if ( i < baseLen ) and ( base[ i ] > #127 ) and
           ( base[ i + 1 ] > #127 ) then
        begin
            res := True;
            Inc( i );
        end
        else
            res := False;

        Inc( i );
    end;

    if ( not res ) and  ( base[ baseLen ] > #127 ) then
        Dec( baseLen );
    base[ 0 ] := Chr( baseLen );

    i := 1;
    res := False;
    while i <= extLen do
    begin
        if ( i < extLen ) and ( ext[ i ] > #127 ) and
           ( ext[ i + 1 ] > #127 ) then
        begin
            res := True;
            Inc( i );
        end
        else
            res := False;

        Inc( i );
    end;

    if ( not res ) and ( ext[ extLen ] > #127 ) then
        Dec( extLen );
    ext[ 0 ] := Chr( extLen );

    msdosName := base + '.' + ext;

    totLen := baseLen + extLen + Ord( extLen > 0 );

    i := 0;
    repeat
        (* Create the next shortname to try *)
        Inc( i );
        if i = 10000000 then
            Exit;

        Str( I, buf );
        sz := Length( buf );
        if sz + 1 > spaces then
        begin
            Dec( baseLen, sz + 1 - spaces );
            spaces := sz + 1;

            j := 1;
            res := False;
            while j <= baseLen do
            begin
                if ( j < baseLen ) and ( base[ j ] > #127 ) and
                   ( base[ j + 1 ] > #127 ) then
                begin
                    res := True;
                    Inc( j );
                end
                else
                    res := False;

                Inc( j );
            end;

            if ( not res ) and  ( base[ baseLen ] > #127 ) then
            begin
                Dec( baseLen );
                Inc( spaces );
            end;
        end;

        msdosName := Copy( base, 1, baseLen ) + '~' + buf + '.' + ext;

        totLen := baseLen + sz + 1 + extLen + Ord( extLen > 0 );
    until not FileExist( FNMerge( dir,  msdosName ));

(*
    if not VFATFormatName( 'x', msdosName, totLen, result ) then
        result := '';
*)
    result := UCase( msdosName );
end;

type
    PVFATSlotArray = ^TVFATSlotArray;
    TVFATSlotArray = array [ 0..$FFF0 ] of TVFATSlot;

procedure VFATMakeLongSlots( name : string; var fe : TFileEntry;
                             var slots : TVFATSlotArray );
const
    secondChar : array [ 0..1 ] of Char = ( #0, #$FF );

var
    uniname     : string;
    nSlots      : Byte;
    Slot        : Byte;
    I, J, K     : Integer;
    chkName     : array[ 0..10 ] of Char;
    checkSum    : Byte;

begin
    Move( fe.Name, chkName, SizeOf( chkName ));

    checkSum := 0;
    for I := 0 to 10 do
    begin
        checkSum := ((( checkSum and 1 ) shl 7 ) or
                   (( checkSum and $FE ) shr 1 )) +
                   Ord( chkName[ I ]);
    end;

    uniname := asc2uni( name );

    nSlots := Length( uniname ) div ( 13 * 2 );

    Slot := nSlots - 1;
    for I := 0 to nSlots - 1 do
    begin
        slots[ Slot ].id := I + 1;
        slots[ Slot ].attr := AttrOfLongFile;
        slots[ Slot ].reserved := 0;
        slots[ Slot ].checkSum := checkSum;
        slots[ Slot ].start := 0;

        K := 0;
        for J := ( I * 13 + 1) to ( I * 13 + 5 ) do
        begin
            slots[ Slot ].name0_4[ K * 2 ] := uniname[ J * 2 - 1 ];
            slots[ Slot ].name0_4[ K * 2 + 1 ] := uniname[ J * 2 ];

            Inc( K );
        end;

        K := 0;
        for J := ( I * 13 + 6 ) to ( I * 13 + 11 ) do
        begin
            slots[ Slot ].name5_10[ K * 2 ] := uniname[ J * 2 - 1];
            slots[ Slot ].name5_10[ K * 2 + 1 ] := uniname[ J * 2 ];

            Inc( K );
        end;

        K := 0;
        for J := ( I * 13 + 12 ) to ( I * 13 + 13 ) do
        begin
            slots[ Slot ].name11_12[ K * 2 ] := uniname[ J * 2 - 1 ];
            slots[ Slot ].name11_12[ K * 2 + 1 ] := uniname[ J * 2 ];

            Inc( K );
        end;

        Dec( Slot );
    end;

    slots[ 0 ].id := slots[ 0 ].id or $40;
end;

function VFATCreateFile( var ff : TFindFile; const name : string; var fe : TFileEntry ) : Boolean;
label
    _release_;

type
    PDataSec2 = ^TDataSec2;
    TDataSec2 = array[ 0..MaxFileEntry * 3 - 1 ] of TFileEntry;

var
    dc, fc, c   : Word;
    freeSlot    : Integer;
    slot        : Integer;
    slots       : PVFATSlotArray;
    sector      : Longint;
    sec         : Longint;
    index       : Integer;
    i           : Integer;
    dataSec     : PDataSec2;

begin
    result := False;

    New( dataSec );
    if dataSec = nil then
        Exit;

    slot := ( Length( asc2uni( name )) div ( 13 * 2 )) + 1;
    GetMem( slots, slot * SizeOf( TVFATSlot ));
    if slots = nil then
        Exit;

    Han2FCB( VFATCreateShortName( ff.dir^, name ), fe.Name );

    VFATMakeLongSlots( name, fe, slots^ );
    Move( fe, slots^[ slot - 1 ], SizeOf( TVFATSlot ));

    sector := 0;
    index := 0;
    freeSlot := 0;

    ff.setName('*.*');
    ff.setAttr( AnyFile );

    ff.FindFirst;
    while ( ff.FindError = fefNoError ) and ( freeSlot < slot ) do
    begin
        if ff.foundEntry^.fileEntry.name[ 0 ] = #$E5 then
        begin
            if freeSlot = 0 then
            begin
                sector := ff.FoundEntry^.sector;
                index := ff.FoundEntry^.index;
            end;

            Inc( freeSlot )
        end
        else
        begin
            sector := 0;
            index := 0;
            freeSlot := 0;
        end;

        ff.FindNext;
    end;

    if sector >= ff.bootInfo^.diskLoc.data then
    begin
        c := ff.sec2clus( ff.startSec );
        while c < ff.LLastCluster do
        begin
            dc := c;
            c := ff.nextFAT( ff.bootInfo^.diskLoc.fat1st, c );
        end;
    end;

    if freeSlot < slot then
    begin
        if freeSlot = 0 then
        begin
            sector := ff.FoundEntry^.sector;
            index := ff.FoundEntry^.index;
        end;

        if sector < ff.bootInfo^.diskLoc.data then
        begin
            freeSlot := ( ff.bootInfo^.diskLoc.data - sector ) * MaxFileEntry -
                        ( index + Ord( freeSlot = 0 ));

            if freeSlot < slot then
                goto _release_;
        end
        else
            freeSlot := ( ff.clus2Sec( dc ) + ff.bootInfo^.boot.spc - sector ) *
                        MaxFileEntry - ( index + Ord( freeSlot = 0 ));

        c := dc;
        fillChar( dataSec^, sizeOf( dataSec^ ), #0 );
        while freeSlot < slot do
        begin
            fc := ff.findFreeFAT( ff.bootInfo^.diskLoc.FAT1st, c + 1 );
            if fc = 0 then
            begin
                if c = dc then
                    goto _release_;

                fc := ff.nextFAT( ff.bootInfo^.diskLoc.FAT1st, dc );

                if not ff.linkAll( dc, ff.GLastCluster ) then
                    goto _release_;

                while fc <> c do
                begin
                    if not ff.linkAll( fc, UnusedCluster ) then
                        goto _release_;

                    fc := ff.nextFAT( ff.bootInfo^.diskLoc.fat1st, fc );
                end;

                ff.linkAll( fc, UnusedCluster );

                goto _release_;
            end;

            if not ff.linkAll( c, fc ) then
                goto _release_;

            for sec := ff.clus2sec( fc ) to
                    ( ff.clus2sec( fc ) + ff.bootInfo^.boot.spc - 1 ) do
                if absWrite( ff.drive, 1, sec, dataSec^ ) <> 0 then
                    goto _release_;

            c := fc;

            Inc( freeSlot, MaxFileEntry * ff.bootInfo^.boot.SPC );
        end;

        if sector >= ff.bootInfo^.diskLoc.data then
            if not ff.linkAll( fc, ff.GLastCluster ) then
                goto _release_;

        if ff.foundEntry^.fileEntry.name[ 0 ] <> #$E5 then
        begin
            Inc( index );
            if index >= MaxFileEntry then
            begin
                index := 0;
                sector := ff.nextSec( ff.bootInfo^.diskLoc.fat1st, sector );
            end;
        end;
    end;

    sec := sector;
    for i := 1 to 3 do
    begin
        if absRead( ff.drive, 1, sec, dataSec^[( i - 1 ) * MaxFileEntry ]) <> 0 then
            goto _release_;

        sec := ff.nextSec( ff.bootInfo^.diskLoc.fat1st, sec );
        if sec = -1 then
            break;
    end;

    Move( slots^, dataSec^[ index ],
          SizeOf( TFileEntry ) * slot );

    sec := sector;
    for i := 1 to 3 do
    begin
        if absWrite( ff.drive, 1, sec, dataSec^[( i - 1 ) * MaxFileEntry ]) <> 0 then
            goto _release_;

        sec := ff.nextSec( ff.bootInfo^.diskLoc.fat1st, sec );
        if sec = -1 then
            break;
    end;

    result := True;

_release_ :

    if dataSec <> nil then
        Dispose( dataSec );

    if slots <> nil then
        FreeMem( slots, slot * SizeOf( TVFATSlot ));
end;

function eraseLongSlot( const path : string ) : Boolean;
label
    _release_;

var
    ff      : PVFATFindFile;
    dataSec : PDataSec;
    sector  : Longint;
    index   : Integer;
    slots   : Integer;

begin
    eraseLongSlot := False;

    if isWild( path ) or ( path = '' ) then
        Exit;

    ff := New( PVFATFindFile, Init( path, AnyFile ));
    if ff = nil then
        Exit;

    New( dataSec );
    if dataSec = nil then
        goto _release_;

    ff^.findFirst;
    if ff^.findError = fefNoError then
    begin
        sector := ff^.foundEntry^.sector;
        index := ff^.foundEntry^.index;
        slots := ff^.foundEntry^.slots;

        if slots < 2 then
        begin
            eraseLongSlot := True;
            goto _release_;
        end;

        if absRead( ff^.fat^.drive, 1, sector, dataSec^ ) <> 0 then
            goto _release_;

        while ( slots > 1 ) and ( sector <> -1 ) do
        begin
            dataSec^[ index ].name[ 0 ] := #$E5;

            Inc( index );
            if index >= MaxFileEntry then
            begin
                if absWrite( ff^.fat^.drive, 1, sector, dataSec^ ) <> 0 then
                    goto _release_;

                index := 0;
                sector := ff^.fat^.nextSec( ff^.fat^.bootInfo^.diskLoc.fat1st, sector );
                if sector <> -1 then
                    if absRead( ff^.fat^.drive, 1, sector, dataSec^ ) <> 0 then
                        goto _release_;

            end;

            Dec( slots );
        end;

        if index > 0 then
            if absWrite( ff^.fat^.drive, 1, sector, dataSec^ ) <> 0 then
                goto _release_;
    end;

    eraseLongSlot := True;

_release_ :

    Dispose( ff, Done );
    Dispose( dataSec );
end;

function fat2VFAT( var ff : TFindFile; const shortName, longName : string ) : Boolean;
var
    dataSec     : PDataSec;
    fe          : TFileEntry;

begin
    fat2VFAT := False;

    if isWild( shortName ) or isWild( longName ) then
        Exit;

    if UCase( shortName ) = UCase( longName ) then
    begin
        fat2VFAT := True;
        Exit;
    end;

    ff.setName( shortName );

    ff.findFirst;
    if ff.findError <> fefNoError then
        Exit;

    New( dataSec );
    if dataSec = nil then
        Exit;

    if absRead( ff.drive, 1, ff.foundEntry^.sector, dataSec^ ) <> 0 then
    begin
        Dispose( dataSec );
        Exit;
    end;

    Move( dataSec^[ ff.foundEntry^.index ], fe, SizeOf( fe ));

    if isShortName( longName ) then
    begin
        han2FCB( longName, dataSec^[ ff.foundEntry^.index ].name );
        if absWrite( ff.drive, 1, ff.foundEntry^.sector, dataSec^ ) <> 0 then
        begin
            Dispose( dataSec );
            Exit;
        end;
    end
    else
    begin
        dataSec^[ ff.foundEntry^.index ].name[ 0 ] := #$E5;
        if absWrite( ff.drive, 1, ff.foundEntry^.sector, dataSec^ ) <> 0 then
        begin
            Dispose( dataSec );
            Exit;
        end;

        if not VFATCreateFile( ff, longName, fe ) then
        begin
            dataSec^[ ff.foundEntry^.index ].name[ 0 ] := UpCase( shortName[ 1 ]);
            absWrite( ff.drive, 1, ff.foundEntry^.sector, dataSec^ );
            Dispose( dataSec );
            Exit;
        end;
    end;

    fat2VFAT := True;
end;

end.
