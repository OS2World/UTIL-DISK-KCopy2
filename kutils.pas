(*
        Collection of simple routines

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

        Source file   : kutils.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

    Change Log :

        Written by KO Myung-Hun
        Term of programming : 1999.05.28

        Source file   : dosunit.pas
        Used compiler : Free Pascal v0.99.10 for OS/2
                        Virtual Pascal v1.1 for OS/2

        Modified by KO Myung-Hun
        Term of programming : 1999.07.04

        Contents :
            added LowCase function.
*)
{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$DELPHI+}
{$ENDIF}
unit KUtils;

interface

uses
    Objects;

    function  UCase( S : string ) : string;
    function  LCase( S : string ) : string;
    function  LowCase( ch : Char ) : Char;
    function  MemCmp( var V1, V2; Len : Cardinal ) : Integer;
    procedure DelLastCh( var S : string; Ch : Char );
    function  PosR( SubStr, S : string ) : Integer;

implementation

function UCase( S : string ) : string;
var
  I : Integer;

begin
  for I := 1 to Length( S ) do
    S[ I ] := UpCase( S[ I ]);

  UCase := S;
end;

function LCase( S : string ) : string;
var
    I : Integer;

begin
    for I := 1 to Length( S ) do
        S[ I ] := LowCase( S[ I ]);

    LCase := S;
end;

function LowCase( ch : Char ) : Char;
begin
    if ch in [ 'A'..'Z' ] then
        ch := Chr( Ord( ch ) + 32 );

    LowCase := ch;
end;


function MemCmp( var V1, V2; Len : Cardinal ): Integer;
var
    I      : Cardinal;
    P1     : Pointer;
    P2     : Pointer;

begin
    P1 := @V1;
    P2 := @V2;
    for I := 1 to Len do
    begin
        Result := Byte( P1^ ) - Byte( P2^ );
        if Result <> 0 then
            Exit;

        Inc( Longint( P1 ));
        Inc( Longint( P2 ));
    end;

    Result := 0;
end;

procedure DelLastCh( var S : string; Ch : Char );
begin
    while ( Length( S ) > 0 ) and ( S[ Length( S )] = Ch ) do
        Dec( S[ 0 ]);
end;

(* Boyer-Moore method *)
function PosR( SubStr, S : string ) : Integer;
const
    MaxCode = $FF;

var
    I, J, Start : Integer;
    Delta       : array [ 0..MaxCode ] of Byte;

begin
    if ( Length( SubStr ) > Length( S )) or ( Length( SubStr ) < 1 ) then
    begin
        PosR := 0;
        Exit;
    end;

    for I := 0 to MaxCode do
        Delta[ I ] := Length( SubStr );

    for I := 1 to Length( SubStr ) do
        Delta[ Ord( SubStr[ I ])] := 1 - I;

    I := Length( S ) - Length( SubStr ) + 1;
    Start := I;
    while I > 0 do
    begin
        J := 1;
        while SubStr[ J ] = S[ I ] do
        begin
            if J = Length( SubStr ) then
            begin
                PosR := Start;
                Exit;
            end;

            Inc( I ); Inc( J );
        end;

        Inc( I, Delta[ Ord( S[ I ])]);
        if I >= Start then
            I := Start - 1;

        Start := I;
    end;

    PosR := 0;
end;

end.

