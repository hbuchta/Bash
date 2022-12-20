{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0à
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: RESUNIT.PAS
Funktion : Unit zur Verwaltung der Ressourcen

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


unit resunit;

interface
{$I-}
uses crt,global;

procedure initressource(s:string);
procedure closeressource;
function load_bitmap(id:word):pointer;
function load_palette(id:word):pointer;
function load_level(id:word):plevel;
function load_font(id:word):pointer;
function load_sample(id:word):pointer;

implementation

var res:file;
    header:pbuffer;
    headersize:word;


procedure cifferread(var f:file; p:pbuffer; size:word);
var i:integer;
begin
blockread(f,p^,size);
for i:=0 to size-1 do
 p^[i]:=p^[i] xor ciffer_string[i and 7];
end;


procedure initressource(s:string);
var b:array[0..7] of byte;
begin
assign(res,s); reset(res,1);
if ioresult<>0 then
 error('ressource file could not be opened');
blockread(res,b[0],8);
if (b[0]<>0) or (b[1]<>$f7) or (b[2]<>$81) or (b[3]<>$11) or (b[4]<>$f8)
 or (b[5]<>0) then error(err_resfile);
headersize:=word(b[6])+256*word(b[7])-8; { Vorspann nicht speichern }
header:=alloc(headersize);
if header=nil then error(err_outofmem);
blockread(res,header^,headersize);
end;



procedure closeressource;
begin
disalloc(header);
close(res);
end;

procedure findressource(typ,handle:word; var ps,size:longint);
var lp:longint; wp:word; hpos:word;
begin
hpos:=0;
{ Suche richtigen Block }
repeat
move(header^[hpos],wp,2); move(header^[hpos+2],lp,4);
if (wp<>0) or (lp<>typ) then begin;
 if wp<>0 then inc(hpos,10) else inc(hpos,6);
 if hpos>=headersize then error(err_resnotfound);
 end;
until (lp=typ);
inc(hpos,6);
repeat
move(header^[hpos],wp,2);
if wp=0 then error(err_resnotfound);
if wp<>handle then begin
 inc(hpos,10); if hpos>=headersize then error(err_resnotfound);
 end;
until (wp=handle);
move(header^[hpos+2],lp,4); ps:=lp;
move(header^[hpos+6],lp,4); size:=lp;
end;


function load_bitmap(id:word):pointer;
var ps,size:longint; p:pbuffer;
begin
findressource(1,id,ps,size);
p:=alloc(size); if p=nil then error(err_outofmem);
seek(res,ps);
cifferread(res,p,size);
load_bitmap:=p;
end;


function load_palette(id:word):pointer;
var ps,size:longint; p:pbuffer;
begin
findressource(2,id,ps,size);
p:=alloc(size); if p=nil then error(err_outofmem);
seek(res,ps);
blockread(res,p^,size);
load_palette:=p;
end;


function load_font(id:word):pointer;
var ps,size:longint; p:pbuffer;
begin
findressource(4,id,ps,size);
p:=alloc(8*128); if p=nil then error(err_outofmem);
seek(res,ps);
blockread(res,p^,8*128);
load_font:=p;
end;


function load_sample(id:word):pointer;
var ps,size:longint; p:pbuffer;
begin
findressource(5,id,ps,size);
p:=alloc(size); if p=nil then error(err_outofmem);
seek(res,ps);
blockread(res,p^,size);
load_sample:=p;
end;


function load_level(id:word):plevel;
var p,p1,p2,pstart:plevel; ps,size:longint;
begin
findressource(3,id,ps,size);
pstart:=nil;
seek(res,ps);
repeat
p1:=alloc(sizeof(tlevel));
if pstart=nil then begin pstart:=p1; p2:=nil; end else p2^.next:=p1;
{blockread(res,p1^,sizeof(tlevel));}
cifferread(res,pbuffer(p1),sizeof(tlevel));
size:=p1^.packsize; p:=p1^.next;
p1^.data:=alloc(size);
{blockread(res,p1^.data^,size);}
cifferread(res,p1^.data,size);
p2:=p1;
until p=nil;
load_level:=pstart;
end;


end.
