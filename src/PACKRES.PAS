{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0‡
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: PACKRES.PAS
Funktion : ZusammenfÅgen der Ressourcen zu BASH.RES

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


uses  dos,global,resfile;
{$M 50000,10000,300000}

const maxres=4;
      res:array[0..maxres] of string=('.pcx','.pal','.lev','.fnt','.pcm');

var   numres,numtypes,hpos:word;
      headersize,filepos:longint;
      header:pbuffer;
      ispresent:array[0..maxres] of boolean;
      f:file;
      totalsize,packsize:longint;
      i:integer;

procedure fail(s:string);
begin
writeln('Fehler in procedure ',s);
halt(1);
end;

function count(s:string):word;
var c:integer; r:Searchrec;
begin
c:=0;
findfirst(mydir+'\res\*'+s,anyfile,r);
while doserror=0 do begin
 inc(c); findnext(r);
 end;
count:=c;
end;


procedure checkres;
var i:integer; n:word;
begin
writeln('Erfassen der Ressourcen...');
numtypes:=0; numres:=0;
for i:=0 to maxres do begin
 n:=count(res[i]);
 if n<>0 then begin ispresent[i]:=true; inc(numtypes); end else
  ispresent[i]:=false;
 inc(numres,n);
 end;
writeln(numres,' Ressourcen insgesamt, ',numtypes,' Typen');
end;


function put_handle(s:string):word;
{ öbertrÑgt das Handle in den Header }
var p:integer; n:word;
begin
p:=pos('.',s); if p=0 then fail('puthandle');
val(copy(s,1,p-1),n,p);
if p<>0 then fail('puthandle');
move(n,header^[hpos],2); inc(hpos,2);
put_handle:=n;
end;


procedure cifferwrite(var f:file; p:pbuffer; size:word);
var i:word;
begin
if size>0 then begin
 for i:=0 to size-1 do
  p^[i]:=p^[i] xor ciffer_string[i and 7];
 blockwrite(f,p^,size);
 for i:=0 to size-1 do
  p^[i]:=p^[i] xor ciffer_string[i and 7];
 end
end;


procedure write_bitmap(id:word);
var p:pbuffer; x,y:word; size:longint;
begin
write(' ',id);
p:=fload_bitmap(id);
x:=word(p^[0])+256*word(p^[1]); y:=word(p^[2])+256*word(p^[3]);
size:=x*y+4; inc(totalsize,size);
move(filepos,header^[hpos],4); inc(hpos,4);
move(size,header^[hpos],4); inc(hpos,4);
cifferwrite(f,p,size);
inc(filepos,size);
inc(packsize,size);
disalloc(p);
end;


procedure write_palette(id:word);
var p:pbuffer; size:longint;
begin
write(' ',id);
p:=fload_palette(id);
size:=256*3; inc(totalsize,size);
move(filepos,header^[hpos],4); inc(hpos,4);
move(size,header^[hpos],4); inc(hpos,4);
blockwrite(f,p^,size);
inc(filepos,size);
inc(packsize,size);
disalloc(p);
end;


procedure write_font(id:word);
var p:pbuffer; size:longint;
begin
write(' ',id);
p:=fload_font(id);
size:=8*128; inc(totalsize,size);
move(filepos,header^[hpos],4); inc(hpos,4);
move(size,header^[hpos],4); inc(hpos,4);
blockwrite(f,p^,size);
inc(filepos,size);
inc(packsize,size);
disalloc(p);
end;





procedure write_level(id:word);
var pl,pl1,pl2:plevel; size:longint;
begin
write(' ',id);
pl:=fload_level(id); pl1:=pl;
size:=0;
while pl1<>nil do begin
 inc(size,sizeof(tlevel));
 inc(size,pl1^.packsize);
 pl1:=pl1^.next;
 end;
move(filepos,header^[hpos],4); inc(hpos,4);
move(size,header^[hpos],4); inc(hpos,4);
pl1:=pl;
while pl1<>nil do begin
 cifferwrite(f,pbuffer(pl1),sizeof(tlevel));
 cifferwrite(f,pl1^.data,pl1^.packsize);
 inc(totalsize,sizeof(tlevel)+pl1^.x*pl1^.y);
 inc(packsize,sizeof(tlevel)+pl1^.packsize);
 pl2:=pl1; disalloc(pl2^.data); disalloc(pl2);
 pl1:=pl1^.next;
 end;
inc(filepos,size);
end;


procedure write_sample(id:word);
var p:pbuffer; size:longint;
begin
write(' ',id);
p:=fload_sample(id);
size:=word(p^[0])+word(p^[1]) shl 8+2;
inc(totalsize,size);
move(filepos,header^[hpos],4); inc(hpos,4);
move(size,header^[hpos],4); inc(hpos,4);
blockwrite(f,p^,size);
inc(filepos,size);
inc(packsize,size);
disalloc(p);
end;




procedure processressources;
var i:integer; r:searchrec; t1:longint; id,t2:word;
begin
for i:=0 to maxres do if ispresent[i] then begin
 { Typ der Ressource speichern }
 t2:=0; move(t2,header^[hpos],2); inc(hpos,2);
 t1:=i+1; move(t1,header^[hpos],4); inc(hpos,4);
 findfirst(mydir+'\res\*'+res[i],anyfile,r);
 case i of
  0: write('Bitmap  :');
  1: write('Palette :');
  2: write('Level   :');
  3: write('Font    :');
  4: write('Sample  :');
  end;
 while doserror=0 do begin
  id:=put_handle(r.name);
  case i of
   0: write_bitmap(id);
   1: write_palette(id);
   2: write_level(id);
   3: write_font(id);
   4: write_sample(id);
   end;
  findnext(r);
  end; { vom while doserror=0 }
 writeln;
 end; { vom for i:=0 to maxres }
t1:=0; move(t1,header^[hpos],4); move(t1,header^[hpos],2);
inc(hpos,6);
end;


begin
{mydir:=fexpand(paramstr(0)); i:=length(mydir);
while mydir[i]<>'\' do dec(i);
mydir:=copy(mydir,1,i-1);}
mydir:='d:\daten\tp\bash';
writeln;
writeln('ƒƒƒƒÕÕÕÕÕÕÕÕÕ  PACKRES 1.0‡  ÕÕÕÕÕÕÕÕÕƒƒƒƒ');
writeln('Hilfsprogramm zu BASH');
writeln('Quellverzeichnis: ',mydir+'\RES');
writeln;
checkres; packsize:=0; totalsize:=0;
headersize:=14+6*numtypes+10*numres;
header:=alloc(headersize);
if header=nil then fail('main (out of memory)');
{assign(f,mydir+'\bash.res');}
assign(f,'c:\bp\output\bash.res');
rewrite(f,1);
{ Der richtige Header wird erst zum Schlu· in die Datei geschrieben -
  hier nur ein Platzhalter:}
blockwrite(f,header^,headersize); filepos:=headersize;
header^[0]:=0; header^[1]:=$f7; header^[2]:=$81; header^[3]:=$11;
header^[4]:=$f8; header^[5]:=0;
move(headersize,header^[6],2); hpos:=8;
processressources;
seek(f,0);
if hpos<>headersize then fail('main (headersize)');
blockwrite(f,header^,headersize);
writeln('HeaderlÑnge ok');
close(f);
writeln('Datengrî·e         : ',totalsize);
writeln('Komprimierte Grî·e : ',packsize);
writeln('Kompr.verhÑltnis   : ',(packsize/totalsize)*100:0:2,' %');
end.
