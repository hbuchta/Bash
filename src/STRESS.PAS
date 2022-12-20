program stress;
uses dos;
{$M 10000,0,0}

type tbuffer=array[0..10000] of byte;
     pbuffer=^tbuffer;
var size:longint; tmp:integer;
    s:String;
    p:pbuffer;
    maxmemseg:word;

procedure error(s:string);
begin
writeln(s);
writeln('Verwendung:');
writeln('stress val');
writeln(' val gibt die neue Speichergrî·e in KB an');
halt(1);
end;




function alloc(size:longint):pointer;
var segment:word; p:pointer;
begin
segment:=size div 16;
if longint(segment)*16<size then inc(segment);
asm
    mov  ax, 4800h
    mov  bx,segment
    int  21h
    jnc  @ok
    xor  ax,ax
    mov  maxmemseg,bx
@ok:mov  segment,ax
end;
alloc:=ptr(segment,0);
end;




begin
writeln('STRESS Environment V1.0 Hilmar Buchta 1994');
if paramcount<1 then error('Fehlender Parameter');
s:=paramstr(1);
val(s,size,tmp);
if tmp<>0 then error('Parameter mu· Grî·e angeben');
size:=size*1024;
p:=alloc($f0000);   { Zuviel Speicher belegen }
p:=alloc(longint(maxmemseg)*16-size);
if p=nil then error('Zu wenig freier Speicher');
p:=ptr(seg(p^)-1,ofs(p^));   { auf MSP zurÅckstellen }
p^[1]:=0; p^[2]:=1;          { als Systemspeicherblock deklarieren }
keep(0);
end.
