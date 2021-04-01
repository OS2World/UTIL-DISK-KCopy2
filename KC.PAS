(*
        File copy program between VFAT and other partitions that OS/2 supports

        Copyright (C) 1999 by KO Myung-Hun

        This program is free software; you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation; either version 2 of the License, or
        any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program; if not, write to the Free Software
        Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

    Environment :

        Source file   : kc.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

    Change Log :

        Written by KO Myung-Hun
        Term of programming : 1999.05.23, 1999.05.28, 1999.07.11, 1999.11.22

        Source file   : kc.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

        History :
            v0.3.0  -   1999.11.26
                        supports copying between same partition

                        bug fix :
                            if a source name include continuous spaces,
                            KCopy/2 recognize that as one space

                            As copying from ordinary parition to vfat
                            partition, directory of long name is not
                            processed correctly

            v0.2.0  -   1999.07.14
                        supports copying other partition to VFAT
                        supports hangul file name
                        do not support special files
                        ( 'WP ROOT. SF' and 'EA DATA. SF' )

                        bug fix :
                            if source filename is 'x:', KCopy/2 do
                            not copy any files.

            v0.1.0  -   1999.05.28
                        supports copying subdirectories

                        bug fix :
                            if source filename don't include wildcard,
                            KCopy/2 operate incorrectly

                        known bugs :
                            supports only 25 level depth of directory.
                            because this version use recursive calling
                            to copy subdirectories, so stack is lack.

            v0.0.0  -   1999.05.23
                        initial version
                        only supports copying VFAT to other partition that
                        OS/2 supports

                        known bugs :
                            if a source name include continuous spaces,
                            KCopy/2 recognize that as one space

*)
{$M 65535}
{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$DELPHI+}
{$ENDIF}
program K_Copy_2;

{$IFDEF FPC}
uses
    Objects, Dos, KUtils, FATUnit, FileUnit, DosCalls;
{$ELSE}
uses
    Objects, Dos, KUtils, FATUnit, FileUnit, Os2Base;
{$ENDIF}

{$IFDEF VPDEMO}
    {$DYNAMIC VP11DEMO.LIB}
{$ENDIF}

type
    PFileItem = ^TFileItem;
    TFileItem = record
        fullPath    : string;
        dir         : string;
        name        : string;
        level       : Integer;
    end;

    PFileCollection = ^TFileCollection;
    TFileCollection = object( TCollection )
        procedure FreeItem( item : Pointer ); virtual;
    end;


procedure TFileCollection.FreeItem( item : Pointer );
var
    fileItem : PFileItem absolute item;

begin
    Dispose( fileItem );
end;

function newFileItem( const fullPath, dir, name : string; level : Integer ) : PFileItem;
var
    fileItem : PFileItem;

begin
    New( fileItem );

    fileItem^.fullPath := fullPath;
    fileItem^.dir := dir;
    fileItem^.name := name;
    fileItem^.level := level;

    result := fileItem;
end;

{$IFDEF FPC}
procedure ParseParam( var CopySubDir : Boolean; var Src, Dest : string );
var
    PTIB : PThreadInfoBlock;
    PPIB : PProcessInfoBlock;

function GetParam( Index : Integer; var Param : string ) : Integer;
var
    Quote : Boolean;
    Ch    : Byte;

begin
    Param := '';

    while PPIB^.Cmd^[ Index ] = Ord( ' ' ) do
        Inc( Index );

    Quote := False;
    while True do
    begin
        Ch := PPIB^.Cmd^[ Index ];
        Inc( Index );

        if ( Ch = 0 ) or (( Ch = Ord( ' ' )) and ( not Quote ))then
            break;

        if Ch = Ord( '"' ) then
            Quote := not Quote
        else
            Param := Param + Chr( Ch );
    end;

    GetParam := Index;
end;

var
    Index : Integer;

begin
    DosGetInfoBlocks( PTIB, PPIB );

    CopySubDir := False;
    Index := GetParam( GetParam( 0, Src ), Src );
    if UCase( Src ) = '/S' then
        CopySubDir := True
    else
        Index := GetParam( 0, Src );

    GetParam( GetParam( Index, Src ), Dest );
end;
{$ELSE}
procedure ParseParam( var CopySubDir : Boolean; var Src, Dest : string );
var
    APTIB : PTIB;
    APPIB : PPIB;

function GetParam( Index : Integer; var Param : string ) : Integer;
var
    Quote : Boolean;
    Ch    : Char;

begin
    Param := '';

    while APPIB^.Pib_pchCmd[ Index ] = ' ' do
        Inc( Index );

    Quote := False;
    while True do
    begin
        Ch := APPIB^.Pib_pchCmd[ Index ];
        Inc( Index );

        if ( Ch = #0 ) or (( Ch = ' ' ) and ( not Quote ))then
            break;

        if Ch = '"' then
            Quote := not Quote
        else
            Param := Param + Ch;
    end;

    GetParam := Index;
end;

var
    Index : Integer;

begin
    DosGetInfoBlocks( APTIB, APPIB );

    CopySubDir := False;
    Index := GetParam( GetParam( 0, Src ), Src );
    if UCase( Src ) = '/S' then
        CopySubDir := True
    else
        Index := GetParam( 0, Src );

    GetParam( GetParam( Index, Src ), Dest );
end;

{$ENDIF}

procedure fromVFAT( copySubDir : Boolean; src : PString; fileCol : PFileCollection );
const
    level       : Integer = 0;

var
    FF          : PVFATFindFile;
    SrcDir      : PString;
    SrcName     : PString;
    SrcSpec     : PString;

begin
    New( SrcDir ); New( SrcSpec ); New( SrcName );

    FF := New( PVFATFindFile, Init( Src^, AnyFile and not VolumeID ));

    FF^.FindFirst;
    if ((( FF^.FindError = fefNoError ) and
        (( FF^.FoundEntry^.VFATFileEntry.FileEntry.Attr and Directory ) = Directory )) or
        ( isDir( src^ ))) and
       ( not IsWild( FF^.Path^ )) then
    begin
        FF^.SetPath( FNMerge( Src^, '*.*' ));

        FF^.FindFirst;
    end;

    SrcDir^ := FF^.dir^;
    SrcSpec^ := GetNameCom( FF^.Path^ );

    while FF^.FindError = fefNoError do
    begin
        if ( FF^.GetName <> '.' ) and ( FF^.GetName <> '..' ) then
        begin
            SrcName^ := FF^.FoundEntry^.VFATFileEntry.shortName;

            if ( srcName^ <> 'EA DATA. SF' ) and
               ( srcName^ <> 'WP ROOT. SF' ) and
               (( FF^.FoundEntry^.VFATFileEntry.FileEntry.Attr and Directory ) = 0) then
                fileCol^.Insert( newFileItem( fnMerge( ff^.shortDir^, srcName^ ),
                                              '', ff^.getName, -1 ));
        end;

        FF^.FindNext;
    end;

    if CopySubDir then
    begin
        FF^.SetAttr( Directory );
        FF^.SetPath( FNMerge( srcDir^, '*.*' ));

        FF^.FindFirst;
        while FF^.FindError = fefNoError do
        begin
            if ( FF^.GetName <> '.' ) and ( FF^.GetName <> '..' ) then
            begin
                SrcName^ := FNMerge( FNMerge( SrcDir^, FF^.GetName ), SrcSpec^ );

                Inc( level );
                fileCol^.Insert( newFileItem( '', fnMerge( srcDir^, ff^.getName ), '', level ));
                fromVFAT( True, srcName, fileCol );
            end;

            FF^.FindNext;
        end;
    end;

    Dispose( SrcDir ); Dispose( SrcSpec ); Dispose( SrcName );

    if FF <> nil then
        Dispose( FF, Done );

    Dec( level );
end;

procedure toVFAT( copySubDir : Boolean; dest : PString; fileCol : PFileCollection );
var
    ff          : PFindFile;
    destDir     : PString;
    destSpec    : PString;
    destName    : PString;
    tempDest    : PString;
    baseDir     : PString;
    exist       : Boolean;
    fileItem    : PFileItem;
    i, j        : Integer;
    p           : Integer;
    rc          : Longint;

begin
    New( destDir ); New( destSpec ); New( destName );
    New( tempDest );
    New( baseDir );

    if dest^ = '' then
        GetDir( 0, dest^ );

    if isWild( getNameCom( dest^ )) then
        destDir^ := fnMerge( getShortPath( getDirCom( dest^ )), getNameCom( dest^ ))
    else
        destDir^ := RmLastBS( getShortPath( dest^ ));

    ff := New( PFindFile, Init( Copy( FExpand( dest^ ), 1, 3 ) + '*.*',
               AnyFile and not VolumeID ));

    if CopySubDir then
    begin
        rc := 0;

        if ( not isWild( destDir^ )) and ( not IsDir( destDir^ )) then
        begin
            {$IFDEF FPC}
            rc := DosCreateDir( destDir^, nil );
            {$ELSE}
            destDir^ := destDir^ + #0;
            rc := DosCreateDir( @destDir^[ 1 ], nil );
            Dec( destDir^[ 0 ]);
            {$ENDIF}

            if rc = 0 then
            begin
                ff^.setPath( destDir^ );

                fat2VFAT( ff^, getNameCom( destDir^ ), getNameCom( dest^ ));
            end;

        end
        else if isWild( destDir^ ) and ( not IsDir( GetDirCom( destDir^ ))) then
        begin
            destDir^ := GetDirCom( destDir^ );
            destName^ := getNameCom( getDirCom( dest^ ));
            {$IFDEF FPC}
            rc := DosCreateDir( destDir^, nil );
            {$ELSE}
            destDir^ := destDir^ + #0;
            rc := DosCreateDir( @destDir^[ 1 ], nil );
            Dec( destDir^[ 0 ]);
            {$ENDIF}

            if rc = 0 then
            begin
                ff^.setPath( destDir^ );

                fat2VFAT( ff^, getNameCom( destDir^ ), destName^ );
            end;
        end;

        if rc <> 0 then
        begin
            WriteLn('Error(', rc, ') : cannot create destination directory (', destDir^, ')');
            Halt( 1 );
        end;
    end;

    if IsDir( getShortPath( dest^ )) then
    begin
        destDir^ := dest^;
        destSpec^ := '*.*';
    end
    else
    begin
        destDir^ := GetDirCom( dest^ );
        destSpec^ := GetNameCom( dest^ );
    end;

    ff^.setDir( getShortPath( destDir^ ));

    baseDir^ := destDir^;
    for i := 1 to fileCol^.count do
    begin
        fileItem := fileCol^.at( i - 1 );

        if fileItem^.level > 0 then
        begin
            p := Length( fileItem^.dir );
            destDir^ := fileItem^.dir;

            j := 0;
            while ( j < fileItem^.level ) and ( p > 0 ) do
            begin
                if destDir^[ p ] in [ '\', ':' ] then
                    Inc( j );

                Dec( p );
            end;

            if j < fileItem^.level then
                Dec( p );

            Delete( destDir^, 1, p + 1 );

            destDir^ := fnMerge( baseDir^, destDir^ );

            tempDest^ := getShortPath( destDir^ );
            if not isDir( tempDest^ ) then
            begin
                {$IFDEF FPC}
                RC := DosCreateDir( tempDest^, nil );
                {$ELSE}
                tempDest^ := tempDest^ + #0;
                RC := DosCreateDir( @tempDest^[ 1 ], nil );
                Dec( tempDest^[ 0 ]);
                {$ENDIF}

                if RC = 0 then
                begin
                    ff^.setPath( tempDest^ );

                    fat2VFAT( ff^, getNameCom( tempDest^ ), getNameCom( destDir^ ));
                end
                else
                begin
                    WriteLn('Error(', RC, ') : cannot create destination directory (', DestDir^, ')');
                    Halt( 1 );
                end;
            end;

            ff^.setDir( tempDest^ );
        end
        else
        begin
            {$IFDEF FPC}
            DosEditName( 1, fileItem^.name, destSpec^, destName^ );
            {$ELSE}
            fileItem^.name := fileItem^.name + #0;
            destSpec^ := destSpec^ + #0;
            DosEditName( 1, @fileItem^.name[ 1 ], @destSpec^[ 1 ], @destName^[ 1 ], 255 );
            Dec( fileItem^.name[ 0 ]);
            Dec( destSpec^[ 0 ]);
            destName^[ 0 ] := #255;
            destName^[ 0 ] := Chr( Pos( #0, destName^ ));
            if destName^[ 0 ] > #0 then
                Dec( destname^[ 0 ]);
            {$ENDIF}
            while destName^[ length( destName^ )] = '.' do
                dec( destName^[ 0 ]);

            WriteLn( fnMerge( GetDirCom( fileItem^.fullPath ), fileItem^.name ), ' => ',
                     FNMerge( destDir^, destName^ ));

(*
            if not eraseLongSlot( fnMerge( destDir^, destName^ )) then
            begin
                WriteLn('Error : cannot clean VFAT entry');
                Halt( 1 );
            end;
*)
            tempDest^ := getShortPath( fnMerge( destDir^, destName^ ));
            exist := fileExist( tempDest^ );
{$IFDEF FPC}
            RC := DosCopy( fileItem^.fullPath, tempDest^, dcExisting );
{$ELSE}
            fileItem^.fullPath := fileItem^.fullPath + #0;
            tempDest^ := tempDest^ + #0;
            RC := DosCopy( @fileItem^.fullPath[ 1 ], @tempDest^[ 1 ], dcpy_Existing );
            Dec( fileItem^.fullPath[ 0 ]);
            Dec( tempDest^[ 0 ]);
{$ENDIF}
            if RC <> 0 then
            begin
                WriteLn( 'Error(', RC, ') : cannot copy file' );
                Halt( 1 );
            end;

            if not exist then
                if not fat2VFAT( ff^, getNameCom( tempDest^ ), destName^ ) then
                begin
                    WriteLn('Error : cannot access FAT in VFAT mode');
                    Halt( 1 );
                end;
        end;
    end;

    Dispose( destDir ); Dispose( destSpec ); Dispose( destName );
    Dispose( tempDest );
    Dispose( baseDir );

    if FF <> nil then
        Dispose( FF, Done );
end;

procedure fromOther( copySubDir : Boolean; src : PString; fileCol : PFileCollection );
const
    level       : Integer = 0;

var
    srcDir      : PString;
    srcName     : PString;
    srcSpec     : PString;
    tempSrc     : PString;
    findBuf     : PFileFindBuf3;
    dh          : Longint;
    attr        : Longint;
    count       : Longint;
    rc          : Longint;

begin
    New( srcDir ); New( srcSpec ); New( srcName );
    New( tempSrc );
    New( findBuf );

    if isDir( src^ ) and not isWild( src^ ) then
        src^ := fnMerge( src^, '*.*' );

    srcDir^ := getDirCom( src^ );
    srcSpec^ := getNameCom( src^ );

    dh := -1;
    attr := AnyFile and not VolumeID;
    count := 1;
    {$IFDEF FPC}
    rc := DosFindFirst( src^, dh, attr, findBuf, SizeOf( TFileFindBuf3 ),
                        count, ilStandard );
    {$ELSE}
    src^ := src^ + #0;
    rc := DosFindFirst( @src^[ 1 ], dh, Attr, findBuf^, SizeOf( TFileFindBuf3 ),
                        count, fil_Standard );
    Dec( src^[ 0 ]);
    {$ENDIF}

    while rc = 0 do
    begin
        {$IFDEF FPC}
        if ( findBuf^.name <> '.' ) and ( findBuf^.name <> '..' ) then
        {$ELSE}
        if ( findBuf^.achname <> '.' ) and ( findBuf^.achname <> '..' ) then
        {$ENDIF}
        begin
            {$IFDEF FPC}
            srcName^ := findBuf^.name;
            {$ELSE}
            srcName^ := findBuf^.achname;
            {$ENDIF}

            if ( srcName^ <> 'EA DATA. SF' ) and
               ( srcName^ <> 'WP ROOT. SF' ) and
               (( findBuf^.AttrFile and Directory ) = 0 ) then
                fileCol^.Insert( newFileItem( fnMerge( srcDir^, srcName^ ), srcDir^, srcName^, -1 ));
        end;

        count := 1;
        {$IFDEF FPC}
        RC := DosFindNext( dh, findBuf, SizeOf( TFileFindBuf3 ), count );
        {$ELSE}
        RC := DosFindNext( dh, findBuf^, SizeOf( TFileFindBuf3 ), count );
        {$ENDIF}
    end;
    DosFindClose( dh );

    if CopySubDir then
    begin
        dh := -1;
        count := 1;
        {$IFDEF FPC}
        rc := DosFindFirst( fnMerge( srcDir^, '*.*' ), dh, Directory or $1000,
                            findBuf, SizeOf( TFileFindBuf3 ), count,
                            ilStandard );
        {$ELSE}
        tempSrc^ := fnMerge( srcDir^, '*.*' ) + #0;
        rc := DosFindFirst( @tempSrc^[ 1 ], dh, Directory or $1000,
                            findBuf^, SizeOf( TFileFindBuf3 ), count,
                            fil_standard );
        {$ENDIF}

        while rc = 0 do
        begin
        {$IFDEF FPC}
            if ( findBuf^.name <> '.' ) and ( findBuf^.name <> '..' ) then
            begin
                srcName^ := FNMerge( FNMerge( srcDir^, findBuf^.name ), srcSpec^ );

                Inc( level );
                fileCol^.Insert( newFileItem( '', fnMerge( srcDir^, findBuf^.name ), '', level ));
                fromOther( True, srcName, fileCol );
            end;

            count := 1;
            rc := DosFindNext( dh, findBuf, SizeOf( TFileFindBuf3 ), count );
        {$ELSE}
            if ( findBuf^.achname <> '.' ) and ( findBuf^.achname <> '..' ) then
            begin
                srcName^ := FNMerge( FNMerge( srcDir^, findBuf^.achname ), srcSpec^ );

                Inc( level );
                fileCol^.Insert( newFileItem( '', fnMerge( srcDir^, findBuf^.achname ), '', level ));
                fromOther( True, srcName, fileCol );
            end;

            count := 1;
            rc := DosFindNext( dh, findBuf^, SizeOf( TFileFindBuf3 ), count );
        {$ENDIF}
        end;
        DosFindClose( dh );
    end;

    Dispose( srcDir ); Dispose( srcSpec ); Dispose( srcName );
    Dispose( tempSrc );
    Dispose( findBuf );

    Dec( level );
end;

procedure toOther( copySubDir : Boolean; dest : PString; fileCol : PFileCollection );
var
    DestDir     : PString;
    DestSpec    : PString;
    DestName    : PString;
    baseDir     : PString;
    fileItem    : PFileItem;
    i, j        : Integer;
    p           : Integer;
    RC          : Longint;

begin
    New( DestDir ); New( DestSpec ); New( DestName );
    New( baseDir );

    if Dest^ = '' then
        GetDir( 0, Dest^ );

    if copySubDir then
    begin
        RC := 0;

        if ( not IsWild( Dest^ )) and ( not IsDir( Dest^ )) then
        begin
            DestDir^ := RmLastBS( Dest^ );
            {$IFDEF FPC}
            RC := DosCreateDir( DestDir^, nil );
            {$ELSE}
            DestDir^ := DestDir^ + #0;
            RC := DosCreateDir( @DestDir^[ 1 ], nil );
            Dec( DestDir^[ 0 ]);
            {$ENDIF}
        end
        else if IsWild( Dest^ ) and ( not IsDir( GetDirCom( Dest^ ))) then
        begin
            DestDir^ := GetDirCom( Dest^ );
            {$IFDEF FPC}
            RC := DosCreateDir( DestDir^, nil );
            {$ELSE}
            DestDir^ := DestDir^ + #0;
            RC := DosCreateDir( @DestDir^[ 1 ], nil );
            Dec( DestDir^[ 0 ]);
            {$ENDIF}
        end;

        if RC <> 0 then
        begin
            WriteLn('Error(', RC, ') : cannot create destination directory (', DestDir^, ')');
            Halt( 1 );
        end;
    end;

    if IsDir( Dest^ ) then
    begin
        DestDir^ := Dest^;
        DestSpec^ := '*.*';
    end
    else
    begin
        DestDir^ := GetDirCom( Dest^ );
        DestSpec^ := GetNameCom( Dest^ );
    end;

    baseDir^ := DestDir^;
    for I := 1 to fileCol^.count do
    begin
        fileItem := fileCol^.at( I - 1 );

        if fileItem^.level > 0 then
        begin
            p := Length( fileItem^.dir );
            DestDir^ := fileItem^.dir;

            j := 0;
            while ( j < fileItem^.level ) and ( p > 0 ) do
            begin
                if destDir^[ p ] in [ '\', ':' ] then
                    Inc( j );

                Dec( p );
            end;

            if j < fileItem^.level then
                Dec( p );

            Delete( destDir^, 1, p + 1 );

            destDir^ := fnMerge( baseDir^, destDir^ );

            if not isDir( destDir^ ) then
            begin
                {$IFDEF FPC}
                RC := DosCreateDir( DestDir^, nil );
                {$ELSE}
                DestDir^ := DestDir^ + #0;
                RC := DosCreateDir( @DestDir^[ 1 ], nil );
                Dec( DestDir^[ 0 ]);
                {$ENDIF}

                if RC <> 0 then
                begin
                    WriteLn('Error(', RC, ') : cannot create destination directory (', DestDir^, ')');
                    Halt( 1 );
                end;
            end;
        end
        else
        begin
            {$IFDEF FPC}
            DosEditName( 1, fileItem^.name, DestSpec^, DestName^ );
            {$ELSE}
            fileItem^.name := fileItem^.name + #0;
            DestSpec^ := DestSpec^ + #0;
            DosEditName( 1, @fileItem^.name[ 1 ], @DestSpec^[ 1 ], @DestName^[ 1 ], 255 );
            Dec( fileItem^.name[ 0 ]);
            Dec( DestSpec^[ 0 ]);
            DestName^[ 0 ] := #255;
            DestName^[ 0 ] := Chr( Pos( #0, DestName^ ));
            if DestName^[ 0 ] > #0 then
                Dec( DestName^[ 0 ]);
            {$ENDIF}

            while destName^[ length( destName^ )] = '.' do
                dec( destName^[ 0 ]);

            WriteLn( FNMerge( GetDirCom( fileItem^.fullPath ), fileItem^.name), ' => ',
                     FNMerge( DestDir^, DestName^ ));

{$IFDEF FPC}
            RC := DosCopy( fileItem^.fullPath,
                            FNMerge( DestDir^, DestName^ ), dcExisting );
{$ELSE}
            fileItem^.fullPath := fileItem^.fullPath + #0;
            DestName^ := FNMerge( DestDir^, DestName^ ) + #0;

            RC := DosCopy( @fileItem^.fullPath[ 1 ], @DestName^[ 1 ], dcpy_Existing );
            Dec( fileItem^.fullPath[ 0 ]);
            Dec( DestName^[ 0 ]);
{$ENDIF}
            if RC <> 0 then
            begin
                WriteLn( 'Error(', RC, ') : cannot copy file' );
                Halt( 1 );
            end;
        end;
    end;

    Dispose( DestDir ); Dispose( DestSpec ); Dispose( DestName );
    Dispose( baseDir );
end;


procedure Run( CopySubDir : Boolean; Src, Dest : PString );
type
    TFromProc = procedure ( copySubDir : Boolean; src : PString; fileCol : PFileCollection );
    TToProc   = procedure ( copySubDir : Boolean; dest : PString; fileCol : PFileCollection );

var
    fromProc    : TFromProc;
    toProc      : TToProc;
    fileCol     : PFileCollection;

begin (* Run *)
    {$IFDEF FPC}
    fromProc := @fromOther;
    toProc   := @toOther;

    if isFAT( Ord( FExpand( src^ )[ 1 ]) - Ord( 'A' )) then
        fromProc := @fromVFAT;

    if isFAT( Ord( FExpand( dest^ )[ 1 ]) - Ord( 'A' )) then
        toProc := @toVFAT;
    {$ELSE}
    fromProc := fromOther;
    toProc   := toOther;

    if isFAT( Ord( FExpand( src^ )[ 1 ]) - Ord( 'A' )) then
        fromProc := fromVFAT;

    if isFAT( Ord( FExpand( dest^ )[ 1 ]) - Ord( 'A' )) then
        toProc := toVFAT;
    {$ENDIF}

    fileCol := New( PFileCollection, Init( 10, 5 ));

    WriteLn('Searching source file(s)...');
    fromProc( copySubDir, src, fileCol );

    WriteLn;

    WriteLn('Copying file(s)...');
    toProc( copySubDir, dest, fileCol );

    Dispose( fileCol, Done );
end;

const
    Major   = '0';
    Minor   = '3';
    Patch   = '0';
    Email   = 'komh@chollian.net';
    Title   = 'K Copy/2 v' + Major + '.' + Minor + '.' + Patch +
              ' free software by KO Myung-Hun' + '(' + Email + ')';
    Usage   = 'Usage : KC [options] source destination';
    Options = #9'/S : copy subdirectories';

var
    CopySubDir  : Boolean;
    Src, Dest   : string;

begin
    ParseParam( CopySubDir, Src, Dest );

    if Src = '' then
    begin
        WriteLn( Title ); WriteLn;
        WriteLn( Usage ); WriteLn;
        WriteLn( Options ); WriteLn;
        Halt( 1 );
    end;

(*
    if not ( IsFAT( Ord( FExpand( src )[ 1 ]) - Ord( 'A' )) xor
       IsFAT( Ord( FExpand( dest )[ 1 ]) - Ord( 'A' ))) then
    begin
        WriteLn('This version doest not supports to copy in same partition');
        Halt( 1 );
    end;
*)
    Run( CopySubDir, @Src, @Dest );
end.
