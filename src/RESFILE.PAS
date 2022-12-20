{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0‡
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: RESUNIT.PAS
Funktion : Unit zur Verwaltung der Ressourcen

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


unit resfile;

interface
{$I-}
uses crt,global;

function fload_bitmap(id:word):pointer;
function fload_palette(id:word):pointer;
function fload_level(id:word):plevel;
function fload_font(id:word):pointer;
function fload_sample(id:word):pointer;

implementation



function fload_bitmap(id:word):pointer;
{ FÅr 256 Farb-Bitmaps im .pcx Format bis zu einer Grî·e von
  320x200 Punkten }
var
  coded:boolean;
  xs,ys,loadsize,j:word;
  b,b1:byte; bufferp,bmp:^byte;
  buffer,bm:pbuffer;
  pcxname:string;
  f:file;
  size,remainsize,i:longint;

begin
fload_bitmap:=nil;
str(id,pcxname); pcxname:=mydir+'\res\'+pcxname+'.pcx';
assign(f,pcxname); reset(f,1);
if IOResult<>0 then exit;
size:=filesize(f)-769; remainsize:=size;
buffer:=alloc(size); if buffer=nil then exit;
bm:=buffer;
while remainsize>0 do begin
 if remainsize>$ffff then loadsize:=$ffff else loadsize:=remainsize;
 blockread(f,bm^,loadsize);
 remainsize:=remainsize-loadsize; incr(pointer(bm),$10000);
 end;
close(f);
if (buffer^[0]<>$0a) then exit;
xs:=(buffer^[8]+256*buffer^[9])-(buffer^[4]+256*buffer^[5]);
ys:=(buffer^[10]+256*buffer^[11])-(buffer^[6]+256*buffer^[7]);
coded:=(buffer^[2]=1);
bm:=alloc((xs+1)*(ys+1)+4); if bm=nil then exit;
inc(xs); inc(ys);
move(xs,bm^[0],2); move(ys,bm^[2],2);
bmp:=pointer(bm); incr(pointer(bmp),4);
bufferp:=pointer(buffer); incr(pointer(bufferp),128);
i:=128;
while (i<size) do begin
b:=bufferp^;
if coded and (b>=$c0) then begin
 dec(b,$c0); incr1(bufferp); b1:=bufferp^; inc(i);
 for j:=1 to b do begin bmp^:=b1; incr1(bmp); end;
 end else begin bmp^:=b; incr1(bmp); end;
 inc(i); incr1(bufferp);
 end;
disalloc(buffer);
fload_bitmap:=bm;
end;


function fload_palette(id:word):pointer;
var palname:string; pal:pbuffer; f:file; size:longint;
    i:integer;
begin
fload_palette:=nil;
pal:=alloc(768); if pal=nil then exit;
str(id,palname); palname:=mydir+'\res\'+palname+'.pal';
assign(f,palname); reset(f,1);
if ioresult<>0 then exit;
size:=filesize(f); seek(f,size-768);
blockread(f,pal^[0],768);
if ioresult<>0 then exit;
close(f);
for i:=0 to 767 do pal^[i]:=pal^[i] div 4;
fload_palette:=pal;
end;


function fload_font(id:word):pointer;
var fontname:string; pal:pbuffer; f:file; size:longint;
    i:integer; font:pointer;
begin
fload_font:=nil;
font:=alloc(8*128); if font=nil then exit;
str(id,fontname); fontname:=mydir+'\res\'+fontname+'.fnt';
assign(f,fontname); reset(f,1);
if ioresult<>0 then exit;
size:=8*128;
blockread(f,font^,8*128);
if ioresult<>0 then exit;
close(f);
fload_font:=font;
end;


function fload_sample(id:word):pointer;
var samplename:string; sam:pbuffer; f:file; size:longint; wsize:word;
    i:integer;
begin
fload_sample:=nil;
str(id,samplename); samplename:=mydir+'\res\'+samplename+'.pcm';
assign(f,samplename); reset(f,1);
if ioresult<>0 then exit;
size:=filesize(f);
if size>20000 then exit;
wsize:=size;
sam:=alloc(wsize+2); if sam=nil then exit;
sam^[0]:=lo(wsize); sam^[1]:=hi(wsize);
blockread(f,sam^[2],size);
if ioresult<>0 then exit;
close(f);
fload_sample:=sam;
end;


function fload_level(id:word):plevel;
var levname,s:string; f:text; p1,p2,p3:plevel;
    dta:array[0..50] of string; b:byte;
    index,ndiam,diam,size,i,j,pos,x,y:integer; ln:word;
begin
fload_level:=nil; p1:=nil; p2:=nil; p3:=nil; ln:=0;
str(id,levname); levname:=mydir+'\res\'+levname+'.lev';
assign(f,levname); reset(f);
if ioresult<>0 then exit;
while not eof(f) do begin
 p2:=alloc(sizeof(tlevel)); if p2=nil then exit;
 readln(f,s); inc(ln);
 if s[1]='*' then begin p2^.enable:=1; s:=copy(s,2,255); end
  else p2^.enable:=0;
 p2^.name:=s;
 readln(f,s); inc(ln); val(s,p2^.timer,index);
 if index<>0 then error('load_level (unreadable timer value)');
 readln(f,s); val(s,ndiam,index);
 if index<>0 then
  error('load_level (number of diamonds unknown)');
 size:=0; diam:=0; index:=-1; x:=0;
 repeat
  readln(f,s); inc(ln);
  if s[1]<>'@' then begin
   index:=index+1;
   if index>50 then error('load_level (level to large)');
   for i:=1 to length(s) do begin
    s[i]:=upcase(s[i]);
    if s[i]='*' then inc(diam);
    end;
    dta[index]:=s; inc(size,length(s));
   if length(s)>x then x:=length(s);
   end;
 until s[1]='@';
 if ndiam<0 then p2^.diam:=diam else p2^.diam:=ndiam;
 inc(index);
 p2^.x:=x; p2^.y:=index; p2^.next:=nil;
 p2^.data:=alloc(x*(index));
 if p2^.data=nil then exit;
 fillchar(p2^.data^,x*index,0);
 for i:=0 to index-1 do move(dta[i][1],p2^.data^[i*x],length(dta[i]));
 size:=x*index; pos:=0;
 for i:=0 to size-1 do begin
  b:=p2^.data^[i]; j:=1;
  while (p2^.data^[i+j]=b) and (j+i<size) and (j<127) do inc(j);
  if j>1 then begin
   p2^.data^[pos]:=byte(j) or 128; p2^.data^[pos+1]:=b;
   inc(i,j-1); inc(pos,2);
   end else begin p2^.data^[pos]:=b; inc(pos); end;
 end;
 p2^.packsize:=pos;
 if p1=nil then begin p1:=p2; p3:=p2; end else
  begin p3^.next:=p2; p3:=p2; end;
  end;
fload_level:=p1;
end;



end.

