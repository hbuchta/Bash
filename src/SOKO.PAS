{Konverter von Sokoban-Leveln zu BASH. Nicht alle Spiele sind danach
spielbar!!!}

uses crt,dos;
var b:array[0..612] of byte;
    f:file;
    i,j,p:integer;
    t:text;
    r:searchrec;

label 1;

begin
assign(t,''); rewrite(t);
findfirst('tab*.*',anyfile,r);
while doserror=0 do begin
if r.size<>612 then goto 1;
assign(f,r.name); reset(f,1);
writeln(t,'*Sokoban-Level');
writeln(t,'1000');
writeln(t,'-1');
blockread(f,b[0],612);
p:=b[0]+256*word(b[1])+2;
b[p]:=ord('S');
p:=b[306]+256*word(b[307])+308;
b[p]:=ord('S');
for i:=2 to 611 do begin
 case b[i] of
  0: b[i]:=32;
  1: b[i]:=ord('X');
  3: b[i]:=ord('W');
 $14: b[i]:=ord('V');
{  else if b[i]<>ord('S') then b[i]:=ord('*');}
 end;
 end;
p:=2;
for i:=0 to 31 do begin
 for j:=0 to 18 do begin
 if p<612 then write(t,chr(b[p]));
 inc(p,1);
 if p=306 then begin
  writeln(t,'');
  writeln(t,'@');
  writeln(t,'*Sokoban-Level');
  writeln(t,'1000');
  writeln(t,'-1');
  inc(p,2); end;
 end;
 writeln(t,'');
 end;
writeln(t,'@');
close(f);
1:
findnext(r);
end;
end.
