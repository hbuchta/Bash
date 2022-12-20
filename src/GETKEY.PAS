{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH  Version 1.0‡
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: GETKEY.PAS
Funktion : Unit fÅr Tastatureingaben

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
unit getkey;
{$G+}
interface
uses crt,dos,global;


procedure inithandler;
procedure removehandler;
function scankey:word;
procedure waitkeyrelease;


const
 k_none=0;
 k_esc=27; k_f1=10; k_f2=11; k_f3=12; k_f4=13; k_f5=14; k_f6=15; k_f7=16;
 k_f8=17; k_f9=18; k_f10=19; k_enter=13; k_backspc=8; k_tab=0;
 k_up=1; k_down=2; k_right=3; k_left=4; k_home=7; k_pgup=5; k_pgdown=6;
 k_end=8;


 status_shift=1;
 status_ctrl=2;

var extstatus:byte;    { EnthÑlt die Bits aus den status_... -Definitionen }

    key,lastkey:word;
    storekeytobuffer:boolean;
implementation

var origint9:pointer;
    oldexitproc:procedure;


const
 scanlist:string=
 chr(0)+chr(k_esc)+'1234567890-='+chr(k_backspc)+chr(k_tab)+'QWERTYUIOP[]'
 +chr(k_enter)+chr(0)+'ASDFGHJKL;'+chr(39)+chr(96)+chr(0)+'\ZXCVBNM,./'
 +chr(0)+'*'+chr(0)+' '+chr(0)+chr(k_f1)+chr(k_f2)+chr(k_f3)+chr(k_f4)
 +chr(k_f5)+chr(k_f6)+chr(k_f7)+chr(k_f8)+chr(k_f9)+chr(k_f10)
 +chr(0)+chr(0)+chr(k_home)+chr(k_up)+chr(k_pgup)+'-'+chr(k_left)
 +'5'+chr(k_right)+'+'+chr(k_end)+chr(k_down)+chr(k_pgdown);


procedure myexitproc; far;
begin
removehandler;
oldexitproc;
end;


procedure Int9handler(Flags, CS, IP, AX, BX,
  CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
var hit,stack:byte;
begin
asm cli end;
hit:=port[$60]; stack:=port[$61];
port[$61]:=stack or $80; port[$61]:=stack;
port[$20]:=$20;
if (hit<>0) and (hit<>224) and (hit and 127<>$2a) and (hit and 127 <>$36)
 then begin
 if (hit=$1d) then extstatus:=extstatus or status_ctrl else
  if (hit=$1d+$80) then
    extstatus:=extstatus and ($ffff-status_ctrl)
  else begin
   if (hit and 128<>0) then begin
    if ((hit and 127)=(key and 255)) then begin
     if storekeytobuffer then lastkey:=key;
     storekeytobuffer:=true;
     key:=0; end;
    end else begin key:=hit or (word(extstatus) shl 8) ; lastkey:=0; end;
  end;
 end;
asm sti end;
end;



procedure inithandler;
begin
getintvec(9,origint9);
setintvec(9,@int9handler);
end;


procedure removehandler;
begin
if origint9<>nil then setintvec(9,origint9);
origint9:=nil;
end;

function scankey:word;
begin
if key=0 then
  scankey:=ord(scanlist[(lastkey and 255)+1])
   or (lastkey and ($ffff-255))
  else
  begin
   scankey:=ord(scanlist[(key and 255)+1])
    or (key and ($ffff-255));
   storekeytobuffer:=false;
   end;
lastkey:=0;
end;


procedure waitkeyrelease;
begin
repeat until key=0;
end;


begin
oldexitproc:=exitptr; exitptr:=myexitproc; extstatus:=0; key:=0; lastkey:=0;
storekeytobuffer:=true;
origint9:=nil;
end.