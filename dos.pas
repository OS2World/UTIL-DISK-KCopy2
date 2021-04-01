{****************************************************************************

    $Id: dos.pas,v 1.13 1999/07/25 17:26:30 KO Myung-Hun Exp $

                         Free Pascal Runtime-Library
                              DOS unit for OS/2
                   Copyright (c) 1997,1998 by Dani�l Mantione,
                   member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 ****************************************************************************}

unit dos;

{$I os.inc}

{$ASMMODE ATT}

{***************************************************************************}

interface

{***************************************************************************}

{$PACKRECORDS 1}

uses    strings;

const   {Bit masks for CPU flags.}
        fcarry      = $0001;
        fparity     = $0004;
        fauxiliary  = $0010;
        fzero       = $0040;
        fsign       = $0080;
        foverflow   = $0800;

        {Bit masks for file attributes.}
        readonly    = $01;
        hidden      = $02;
        sysfile     = $04;
        volumeid    = $08;
        directory   = $10;
        archive     = $20;
        anyfile     = $3F;

        fmclosed    = $D7B0;
        fminput     = $D7B1;
        fmoutput    = $D7B2;
        fminout     = $D7B3;

type    {Some string types:}
        comstr=string;              {Filenames can be long in OS/2.}
        pathstr=string;             {String for pathnames.}
        dirstr=string;              {String for a directory}
        namestr=string;             {String for a filename.}
        extstr=string[40];          {String for an extension. Can be 253
                                     characters long, in theory, but let's
                                     say fourty will be enough.}

        {Search record which is used by findfirst and findnext:}
        searchrec=record
            fill:array[1..21] of byte;
            attr:byte;
            time:longint;
            size:longint;
            name:string;            {Filenames can be long in OS/2!}
        end;

{$i filerec.inc}
{$i textrec.inc}

        {Data structure for the registers needed by msdos and intr:}
       registers=record
            case i:integer of
                0:(ax,f1,bx,f2,cx,f3,dx,f4,bp,f5,si,f51,di,f6,ds,f7,es,
                   f8,flags,fs,gs:word);
                1:(al,ah,f9,f10,bl,bh,f11,f12,cl,ch,f13,f14,dl,dh:byte);
                2:(eax,ebx,ecx,edx,ebp,esi,edi:longint);
            end;

        {Record for date and time:}
        datetime=record
            year,month,day,hour,min,sec:word;
        end;

        {Flags for the exec procedure:

        Starting the program:
        efwait:        Wait until program terminates.
        efno_wait:     Don't wait until the program terminates. Does not work
                       in dos, as DOS cannot multitask.
        efoverlay:     Terminate this program, then execute the requested
                       program. WARNING: Exit-procedures are not called!
        efdebug:       Debug program. Details are unknown.
        efsession:     Do not execute as child of this program. Use a seperate
                       session instead.
        efdetach:      Detached. Function unknown. Info wanted!
        efpm:          Run as presentation manager program.

        Determining the window state of the program:
        efdefault:     Run the pm program in it's default situation.
        efminimize:    Run the pm program minimized.
        efmaximize:    Run the pm program maximized.
        effullscreen:  Run the non-pm program fullscreen.
        efwindowed:    Run the non-pm program in a window.

        Other options are not implemented defined because lack of
        knowledge abou what they do.}

        type    execrunflags=(efwait,efno_wait,efoverlay,efdebug,efsession,
                              efdetach,efpm);
                execwinflags=(efdefault,efminimize,efmaximize,effullscreen,
                              efwindowed);

var doserror:integer;
    dosexitcode:word;

procedure getdate(var year,month,day,dayofweek:word);
procedure gettime(var hour,minute,second,sec100:word);
function dosversion:word;
procedure setdate(year,month,day:word);
procedure settime(hour,minute,second,sec100:word);
procedure getcbreak(var breakvalue:boolean);
procedure setcbreak(breakvalue:boolean);
procedure getverify(var verify:boolean);
procedure setverify(verify : boolean);
function diskfree(drive:byte):longint;
function disksize(drive:byte):longint;
procedure findfirst(const path:pathstr;attr:word;var f:searchRec);
procedure findnext(var f:searchRec);
procedure findclose(var f:searchRec);

{Is a dummy:}
procedure swapvectors;

{Not supported:
procedure getintvec(intno:byte;var vector:pointer);
procedure setintvec(intno:byte;vector:pointer);
procedure keep(exitcode:word);
}
procedure msdos(var regs:registers);
procedure intr(intno : byte;var regs:registers);

procedure getfattr(var f;var attr:word);
procedure setfattr(var f;attr:word);

function fsearch(path:pathstr;dirlist:string):pathstr;
procedure getftime(var f;var time:longint);
procedure setftime(var f;time:longint);
procedure packtime (var d:datetime; var time:longint);
procedure unpacktime (time:longint; var d:datetime);
function fexpand(const path:pathstr):pathstr;
procedure fsplit(path:pathstr;var dir:dirstr;var name:namestr;
                 var ext:extstr);
procedure exec(const path:pathstr;const comline:comstr);
function exec(path:pathstr;runflags:execrunflags;winflags:execwinflags;
              const comline:comstr):longint;
function envcount:longint;
function envstr(index:longint) : string;
function getenv(const envvar:string): string;

implementation

uses    doscalls;

{Import syscall to call it nicely from assembler procedures.}

procedure syscall;external name '___SYSCALL';


function fsearch(path:pathstr;dirlist:string):pathstr;

var i,p1:longint;
    s:searchrec;
    newdir:pathstr;

begin
    {No wildcards allowed in these things:}
    if (pos('?',path)<>0) or (pos('*',path)<>0) then
        fsearch:=''
    else
        begin
            { allow slash as backslash }
            for i:=1 to length(dirlist) do
                if dirlist[i]='/' then dirlist[i]:='\';
            repeat
                p1:=pos(';',dirlist);
                if p1<>0 then
                    begin
                        newdir:=copy(dirlist,1,p1-1);
                        delete(dirlist,1,p1);
                    end
                else
                    begin
                        newdir:=dirlist;
                        dirlist:='';
                    end;
                if (newdir<>'') and
                 not (newdir[length(newdir)] in ['\',':']) then
                    newdir:=newdir+'\';
                findfirst(newdir+path,anyfile,s);
                if doserror=0 then
                    newdir:=newdir+path
                else
                    newdir:='';
            until (dirlist='') or (newdir<>'');
            fsearch:=newdir;
        end;
end;

procedure getftime(var f;var time:longint);

begin
    asm
        {Load handle}
        movl f,%ebx
        movw (%ebx),%bx
        {Get date}
        movw $0x5700,%ax
        call syscall
        shll $16,%edx
        movw %cx,%dx
        movl time,%ebx
        movl %edx,(%ebx)
        xorb %ah,%ah
        movw %ax,doserror
    end;
end;

procedure setftime(var f;time : longint);

begin
    asm
        {Load handle}
        movl f,%ebx
        movw (%ebx),%bx
        movl time,%ecx
        shldl $16,%ecx,%edx
        {Set date}
        movw $0x5701,%ax
        call syscall
        xorb %ah,%ah
        movw %ax,doserror
    end;
end;

procedure msdos(var regs:registers);

{Not recommended for EMX. Only works in DOS mode, not in OS/2 mode.}

begin
    intr($21,regs);
end;

{$ASMMODE DIRECT}

procedure intr(intno:byte;var regs:registers);

{Not recommended for EMX. Only works in DOS mode, not in OS/2 mode.}

begin
    asm
        .data
    int86:
        .byte        0xcd
    int86_vec:
        .byte        0x03
        jmp        int86_retjmp

        .text
        movl        8(%ebp),%eax
        movb        %al,int86_vec

        movl        10(%ebp),%eax
        {Do not use first int}
        incl        %eax
        incl        %eax

        movl        4(%eax),%ebx
        movl        8(%eax),%ecx
        movl        12(%eax),%edx
        movl        16(%eax),%ebp
        movl        20(%eax),%esi
        movl        24(%eax),%edi
        movl        (%eax),%eax

        jmp        int86
    int86_retjmp:
        pushf
        pushl   %ebp
        pushl       %eax
        movl        %esp,%ebp
        {Calc EBP new}
        addl        $12,%ebp
        movl        10(%ebp),%eax
        {Do not use first int}
        incl        %eax
        incl        %eax

        popl        (%eax)
        movl        %ebx,4(%eax)
        movl        %ecx,8(%eax)
        movl        %edx,12(%eax)
        {Restore EBP}
        popl    %edx
        movl    %edx,16(%eax)
        movl        %esi,20(%eax)
        movl        %edi,24(%eax)
        {Ignore ES and DS}
        popl        %ebx            {Flags.}
        movl        %ebx,32(%eax)
        {FS and GS too}
    end;
end;

{$ASMMODE ATT}

procedure exec(const path:pathstr;const comline:comstr);

{Execute a program.}

begin
    dosexitcode:=exec(path,efwait,efdefault,comline);
end;

function exec(path:pathstr;runflags:execrunflags;winflags:execwinflags;
              const comline:comstr):longint;

{Execute a program. More suitable for OS/2 than the exec above.}

{512 bytes should be enough to contain the command-line.}

type    bytearray=array[0..8191] of byte;
        Pbytearray=^bytearray;

        execstruc=record
            argofs,envofs,nameofs:pointer;
            argseg,envseg,nameseg:word;
            numarg,sizearg,
            numenv,sizeenv:word;
            mode1,mode2:byte;
        end;

var args:Pbytearray;
    env:Pbytearray;
    i,j:word;
    es:execstruc;
    esadr:pointer;
    d:dirstr;
    n:namestr;
    e:extstr;

begin
    getmem(args,512);
    getmem(env,8192);
    j:=1;

    {Now setup the arguments. The first argument should be the program
     name without directory and extension.}
    fsplit(path,d,n,e);
    es.numarg:=1;
    args^[0]:=$80;
    for i:=1 to length(n) do
        begin
            args^[j]:=byte(n[i]);
            inc(j);
        end;
    args^[j]:=0;
    inc(j);
    {Now do the real arguments.}
    i:=1;
    while i<=length(comline) do
        begin
            if comline[i]<>' ' then
                begin
                    {Commandline argument found. Copy it.}
                    inc(es.numarg);
                    args^[j]:=$80;
                    inc(j);
                    while (i<=length(comline)) and (comline[i]<>' ') do
                        begin
                            args^[j]:=byte(comline[i]);
                            inc(j);
                            inc(i);
                        end;
                    args^[j]:=0;
                    inc(j);
                end;
            inc(i);
        end;
    args^[j]:=0;
    inc(j);

    {Commandline ready, now build the environment.

     Oh boy, I always had the opinion that executing a program under Dos
     was a hard job!}

    {$ASMMODE DIRECT}

    asm
        movl env,%edi       {Setup destination pointer.}
        movl _envc,%ecx     {Load number of arguments in edx.}
        movl _environ,%esi  {Load env. strings.}
        xorl %edx,%edx      {Count environment size.}
    exa1:
        lodsl               {Load a Pchar.}
        xchgl %eax,%ebx
    exa2:
        movb (%ebx),%al     {Load a byte.}
        incl %ebx           {Point to next byte.}
        stosb               {Store it.}
        incl %edx           {Increase counter.}
        cmpb $0,%al         {Ready ?.}
        jne exa2
        loop exa1           {Next argument.}
        stosb               {Store an extra 0 to finish. (AL is now 0).}
        incl %edx
        movl %edx,(24)es    {Store environment size.}
    end;

    {$ASMMODE ATT}

    {Environtment ready, now set-up exec structure.}
    es.argofs:=args;
    es.envofs:=env;
    asm
        leal path,%esi
        lodsb
        movzbl %al,%eax
        addl %eax,%esi
        movb $0,(%esi)
    end;
    es.nameofs:=pointer(longint(@path)+1);
    asm
        movw %ss,es.argseg
        movw %ss,es.envseg
        movw %ss,es.nameseg
    end;
    es.sizearg:=j;
    es.numenv:=0;
    {Typecasting of sets in FPK is a bit hard.}
    es.mode1:=byte(runflags);
    es.mode2:=byte(winflags);

    {Now exec the program.}
    asm
        leal es,%edx
        mov $0x7f06,%ax
        call syscall
        xorl %edi,%edi
        jnc .Lexprg1
        xchgl %eax,%edi
        xorl %eax,%eax
        decl %eax
    .Lexprg1:
        movw %di,doserror
        movl %eax,__RESULT
    end;

    freemem(args,512);
    freemem(env,8192);
    {Phew! That's it. This was the most sophisticated procedure to call
     a system function I ever wrote!}
end;

function dosversion:word;assembler;

{Returns DOS version in DOS and OS/2 version in OS/2}
asm
    movb $0x30,%ah
    call syscall
end;

procedure getdate(var year,month,day,dayofweek:word);

begin
    asm
        movb $0x2a,%ah
        call syscall
        xorb %ah,%ah
        movl 20(%ebp),%edi
        stosw
        movl 16(%ebp),%edi
        movb %dl,%al
        stosw
        movl 12(%ebp),%edi
        movb %dh,%al
        stosw
        movl 8(%ebp),%edi
        xchgw %ecx,%eax
        stosw
    end;
end;

procedure setdate(year,month,day : word);

begin
    {DOS only! You cannot change the system date in OS/2!}
    asm
        movw 8(%ebp),%cx
        movb 10(%ebp),%dh
        movb 12(%ebp),%dl
        movb $0x2b,%ah
        call syscall
        xorb %ah,%ah
        movw %ax,doserror
    end;
end;

procedure gettime(var hour,minute,second,sec100:word);

begin
    asm
        movb $0x2c,%ah
        call syscall
        xorb %ah,%ah
        movl 20(%ebp),%edi
        movb %dl,%al
        stosw
        movl 16(%ebp),%edi
        movb %dh,%al
        stosw
        movl 12(%ebp),%edi
        movb %cl,%al
        stosw
        movl 8(%ebp),%edi
        movb %ch,%al
        stosw
    end;
end;

procedure settime(hour,minute,second,sec100:word);

begin
    asm
        movb 8(%ebp),%ch
        movb 10(%ebp),%cl
        movb 12(%ebp),%dh
        movb 14(%ebp),%dl
        movb $0x2d,%ah
        call syscall
        xorb %ah,%ah
        movw %ax,doserror
    end;
end;

procedure getcbreak(var breakvalue:boolean);

begin
     {! Do not use in OS/2. Also not recommended in DOS. Use
        signal handling instead.}
    asm
        movw $0x3300,%ax
        call syscall
        movl 8(%ebp),%eax
        movb %dl,(%eax)
    end;
end;

procedure setcbreak(breakvalue:boolean);

begin
    {! Do not use in OS/2. Also not recommended in DOS. Use
       signal handling instead.}
    asm
        movb 8(%ebp),%dl
        movw $0x3301,%ax
        call syscall
    end;
end;

procedure getverify(var verify:boolean);

begin
    {! Do not use in OS/2.}
    asm
        movb $0x54,%ah
        call syscall
        movl 8(%ebp),%edi
        stosb
    end;
end;

procedure setverify(verify:boolean);

begin
    {! Do not use in OS/2.}
    asm
        movb 8(%ebp),%al
        movb $0x2e,%ah
        call syscall
    end;
end;

function diskfree(drive:byte):longint;

var fi:TFSinfo;

begin
    if os_mode=osDOS then
    {Function 36 is not supported in OS/2.}
        asm
            movb 8(%ebp),%dl
            movb $0x36,%ah
            call syscall
            cmpw $-1,%ax
            je .LDISKFREE1
            mulw %cx
            mulw %bx
            shll $16,%edx
            movw %ax,%dx
            xchgl %edx,%eax
            leave
            ret
         .LDISKFREE1:
            cltd
            leave
            ret
        end
    else
        {In OS/2, we use the filesystem information.}
        begin
            doserror:=dosqueryFSinfo(drive,1,FI,sizeof(FI));
            if doserror=0 then
                diskfree:=FI.free_clusters*FI.sectors_per_cluster*
                 FI.bytes_per_sector
            else
                diskfree:=-1;
        end;
end;

function disksize(drive:byte):longint;

var fi:TFSinfo;

begin
    if os_mode=osDOS then
        {Function 36 is not supported in OS/2.}
        asm
            movb 8(%ebp),%dl
            movb $0x36,%ah
            call syscall
            movw %dx,%bx
            cmpw $-1,%ax
            je .LDISKSIZE1
            mulw %cx
            mulw %bx
            shll $16,%edx
            movw %ax,%dx
            xchgl %edx,%eax
            leave
            ret
        .LDISKSIZE1:
            cltd
            leave
            ret
        end
    else
        {In OS/2, we use the filesystem information.}
        begin
            doserror:=dosqueryFSinfo(drive,1,FI,sizeof(FI));
            if doserror=0 then
                disksize:=FI.total_clusters*FI.sectors_per_cluster*
                 FI.bytes_per_sector
            else
                disksize:=-1;
        end;
end;

procedure searchrec2dossearchrec(var f:searchrec);

const   namesize=255;

var l,i:longint;

begin
    l:=length(f.name);
    for i:=1 to namesize do
        f.name[i-1]:=f.name[i];
    f.name[l]:=#0;
end;

procedure dossearchrec2searchrec(var f : searchrec);

const namesize=255;

var l,i : longint;

begin
    for i:=0 to namesize do
        if f.name[i]=#0 then
            begin
                l:=i;
                break;
            end;
    for i:=namesize-1 downto 0 do
        f.name[i+1]:=f.name[i];
    f.name[0]:=char(l);
end;

procedure findfirst(const path:pathstr;attr:word;var f:searchRec);

    procedure _findfirst(path:pchar;attr:word;var f:searchrec);

    begin
        asm
            movl 12(%esp),%edx
            movw 16(%esp),%cx
            {No need to set DTA in EMX. Just give a pointer in ESI.}
            movl 18(%ebp),%esi
            movb $0x4e,%ah
            call syscall
            jnc .LFF
            movw %ax,doserror
        .LFF:
        end;
    end;

var path0:array[0..255] of char;

begin
    {No error.}
    doserror:=0;
    strPcopy(path0,path);
    _findfirst(path0,attr,f);
    dossearchrec2searchrec(f);
end;

procedure findnext(var f:searchRec);

    procedure _findnext(var f : searchrec);

    begin
        asm
            movl 12(%ebp),%esi
            movb $0x4f,%ah
            call syscall
            jnc .LFN
            movw %ax,doserror
        .LFN:
        end;
    end;

begin
    {No error}
    doserror:=0;
    searchrec2dossearchrec(f);
    _findnext(f);
    dossearchrec2searchrec(f);
end;

procedure findclose(var f:searchRec);
begin
end;

procedure swapvectors;

{For TP compatibility, this exists.}

begin
end;

type    PPchar=^Pchar;

{$ASMMODE DIRECT}

function envs:PPchar;assembler;

asm
    movl _environ,%eax
end ['EAX'];

function envcount:longint;assembler;

var hp : ppchar;

asm
    movl _envc,%eax
end ['EAX'];

{$ASMMODE ATT}

function envstr(index : longint) : string;

var hp:PPchar;

begin
    if (index<=0) or (index>envcount) then
        begin
            envstr:='';
            exit;
        end;
    hp:=envs+4*(index-1);
    envstr:=strpas(hp^);
end;

function getenv(const envvar : string) : string;

var hs,_envvar : string;
    eqpos,i : longint;

begin
    _envvar:=upcase(envvar);
    getenv:='';
    for i:=1 to envcount do
        begin
            hs:=envstr(i);
            eqpos:=pos('=',hs);
            if copy(hs,1,eqpos-1)=_envvar then
                begin
                    getenv:=copy(hs,eqpos+1,length(hs)-eqpos);
                    exit;
                end;
        end;
end;

procedure fsplit(path:pathstr;var dir:dirstr;var name:namestr;
                 var ext:extstr);

var p1,i : longint;

begin
    {Get drive name}
    p1:=pos(':',path);
    if p1>0 then
        begin
            dir:=path[1]+':';
            delete(path,1,p1);
        end
    else
        dir:='';
    { split the path and the name, there are no more path informtions }
    { if path contains no backslashes                                 }
    while true do
        begin
            p1:=pos('\',path);
            if p1=0 then
                p1:=pos('/',path);
            if p1=0 then
                break;
            dir:=dir+copy(path,1,p1);
              delete(path,1,p1);
        end;
    {Try to find an extension.}
    ext:='';
    for i:=length(path) downto 1 do
        if path[i]='.' then
            begin
                ext:=copy(path,i,high(extstr));
                delete(path,i,length(path)-i+1);
                break;
            end;
    name:=path;
end;

function fexpand(const path:pathstr):pathstr;

    function get_current_drive:byte;assembler;

    asm
        movb $0x19,%ah
        call syscall
    end;

var s,pa:string;
    i,j:longint;

begin
    getdir(0,s);
    pa:=upcase(path);
    {Allow slash as backslash}
    for i:=1 to length(pa) do
        if pa[i]='/' then
            pa[i]:='\';
    if (length(pa)>1) and (pa[1] in ['A'..'Z']) and (pa[2]=':') then
        begin
            {We must get the right directory}
            getdir(byte(pa[1])-byte('A')+1,s);
            if pa[ 0 ] = #2 then
                pa := s
            else                           
            if (byte(pa[0])>2) and (pa[3]<>'\') then
                if pa[1]=s[1] then
                begin                      
                    if s[ 0 ] = #3 then    
                        Dec( s[ 0 ]);      

                    pa:=s+'\'+copy (pa,3,length(pa))
                end                        
                else
                    pa:=pa[1]+':\'+copy (pa,3,length(pa))
        end
    else
        if pa[1]='\' then
            pa:=s[1]+':'+pa
        else if s[0]=#3 then
            pa:=s+pa
        else
            pa:=s+'\'+pa;
    {First remove all references to '\.\'}
    i:=pos('\.\',pa);
    while i<>0 do
        begin
            delete(pa,i,2);
            i:=pos('\.\',pa);
        end;
    {Now remove also all references to '\..\' + of course previous dirs..}
    repeat
        i:=pos('\..\',pa);
        if i<>0 then
            begin
                j:=i-1;
                while (j>1) and (pa[j]<>'\') do
                    dec(j);
                delete (pa,j,i-j+3);
            end;
    until i=0;

    fexpand:=pa;
end;

procedure packtime(var d:datetime;var time:longint);

var zs:longint;

begin
    time:=-1980;
    time:=time+d.year and 127;
    time:=time shl 4;
    time:=time+d.month;
    time:=time shl 5;
    time:=time+d.day;
    time:=time shl 16;
    zs:=d.hour;
    zs:=zs shl 6;
    zs:=zs+d.min;
    zs:=zs shl 5;
    zs:=zs+d.sec div 2;
    time:=time+(zs and $ffff);
end;

procedure unpacktime (time:longint;var d:datetime);

begin
    d.sec:=(time and 31) * 2;
    time:=time shr 5;
    d.min:=time and 63;
    time:=time shr 6;
    d.hour:=time and 31;
    time:=time shr 5;
    d.day:=time and 31;
    time:=time shr 5;
    d.month:=time and 15;
    time:=time shr 4;
    d.year:=time+1980;
end;

procedure getfattr(var f;var attr : word);assembler;

asm
    movw $0x4300,%ax
    movl f,%edx
    {addl $filerec.name,%edx Doesn't work!!}
    addl $60,%edx
    call syscall
    movl attr,%ebx
    movw %cx,(%ebx)
end;

procedure setfattr(var f;attr : word);assembler;

asm
    movw $0x4301,%ax
    movl f,%edx
    {addl $filerec.name,%edx Doesn't work!!}
    addl $60,%edx
    movw attr,%cx
    call syscall
end;

end.
{
  $Log: dos.pas,v $
  Revision 1.13  1999/07/25 17:26:30 KO Myung-Hun
    * FExpand bug fixed
        if path is 'x:dir', then return value is 'x:\\dir'
        if pa is 'x:\', then return value is 'x:'

    - removed routine to end '.' and '\' from FExpand,
      because BP 7.0 does not so.

  Revision 1.12  1999/01/22 16:25:58  pierre
   + findclose added

  Revision 1.11  1999/01/18 16:22:51  jonas
    - removed "noattcdq" define

  Revision 1.10  1998/12/10 16:05:39  daniel
  * Fsearch bug fixed

  Revision 1.9  1998/12/07 18:55:41  jonas
    * fixed bug reported in the mailing list by Frank McCormick (fsearch: changed
      "if p1 = 0" to "if p1 <> 0"

  Revision 1.8  1998/10/16 14:18:02  daniel
  * Updates

  Revision 1.7  1998/07/08 14:44:11  daniel
  + Added moucalls and viocalls written by Tomas Hajny.
  + Final routines in doscalls implemented.
  * Fixed bugs in dos.pas.
  * Changed some old $ifdef FPK into $ifdef FPC.
  - Removed go32 stuff from dos.pas.
  - Removed '/' to '\' translation from system unit - EMX does this
  automatically.

}
