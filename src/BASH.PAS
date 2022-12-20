{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: BASH.PAS
Funktion : Hauptprogramm

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


{$G+}                  {80286 Code generieren}
{$M 20000,1000,1000}   {Mini-Heap fÅr Sounddriver}
{$I-}                  {Keine ÅberflÅssigen Runtime-Errors!!!}

uses crt,dos,global,vga256,resunit,getkey,joystick,sndriver;

(*
{$DEFINE DEBUGMODE}
*)

type  tactionlstentry=record
       x,y,dx,dy,tp,action:integer;
       id:char;
       end;
{ action-Feld:
 0:Bewegung, <>0:Bewegung und VerÑnderung }
      texplodeentry=record
       x,y,tp:integer;
       end;


const maxactlst=200;    { EintrÑge fÅr Bewegungen }
      maxexplst=40;     { EintrÑge fÅr Explosionen }
      maxbitindex=34;

var bitm:array[0..maxbitindex] of pbuffer;

    vid_y_ofs:integer;
    screen_x,screen_y         { Index der linken oberen Ecke }
     :integer;


    actptr:integer;                    { Anz. EintrÑge in Aktionsliste }
    actlst                             { Aktionsliste }
     :array[0..maxactlst] of tactionlstentry;
    explodeptr,explodeptr1:integer;
    explist,explist1,tmpexp                   { Anzahl Explosionen }
     :array[0..maxexplst] of texplodeentry;   { Koordinaten der Explosionen }


    mainpalette:pbuffer;  { Palette wÑhrend des Spiels }

    mons:array[0..8] of byte;


{******* Variablen der Spielfigur *******}
    timer,                     { Restzeit in Sekunden }
    oldtimersec                { Letzter Sekundenwert }
     :integer;
    player_x,player_y,         { Koordinaten des Spielers im Spielfeld }
    player_dp,                 { Richtung des Spielers }
    player_bitofs,             { FÅr énderungen der Spielfigur }
    neededdiam,                { Noch benîtigte Diamanten }
    noactioncounter            { ZÑhlt die Schritte, in denen die Spielfigur
                                 nicht bewegt wurde }
     :integer;
    lev:tlevel;                { aktueller Level }
    all_level:plevel;          { SÑmtliche Spiele als lineare Liste }
    levx,levy:integer;         { AbkÅrzung fÅr lev.x, lev.y }
    status:integer;            { Zustand nach Verlassen eines Spiels
                                1: Level geschafft
                                2: Abbruch
                                3: Spieler tot...
                                4: Spieler tot in nÑchstem Zug
                                }

    currentlevel:plevel;      { Aktueller Level, wird nach lev kopiert }
    snddrvnum:integer;

    gamesolved:boolean;       { FÅr Endbitmap }
    ctrlflag:boolean;

{ interne Variablen fÅr die Darstellungsschleife }
var i,j,strcount1,strcount2,top,mrk:integer;
    tmp1,tmp2:word; imbuf1,imbuf2:pbuffer;
    c:char; keydown:boolean;
    maxlevel,maxlevelintern:word;
    savegame_list:array[0..7] of string[19];



const
  dir:array[0..3,0..1] of integer= ((1,0),(0,-1),(-1,0),(0,1));
  folge:array[0..3] of integer=(2,3,1,0);


  bitmaps:array[0..maxbitindex] of integer=
   (51,50,100,130,131,132,133,134,135,136,137,138,
    145,146,102,139,140,141,142,143,   { <-- neue WÑnde, verschiebbare zuerst, dann Konverter }

    101,103,104,105,106,107,108,109,110,111,120,180,160,200,202);

id_arrow=0;
id_statusline=1;
id_wall1=2;
id_wall2=3;
id_wall3=4;
id_wall4=5;
id_wall5=6;
id_wall6=7;
id_wall7=8;
id_wall8=9;
id_wall9=10;
id_wall10=11;
id_wallmove=12;
id_wallconvert=13;
id_brick=14;
id_wall11=15;
id_wall12=16;
id_wall13=17;
id_wall14=18;
id_wall15=19;
id_blank=20;
id_brick2=21;
id_exit=22;
id_space=23;
id_stone=24;
id_diamond=25;
id_monster=26;
id_monster2=27;
id_explode=28;
id_converter=29;
id_bomb=30;
id_clock=31;
id_shit=32;
id_player=33;
id_angryplayer=34;




const joystvx=90;
      joystvy=90;
var   oldbutton2:boolean;


function getinput:char;
var c:char; key:word; dx,dy:integer;
begin
key:=scankey;
if key and (word(status_ctrl) shl 8)<>0 then ctrlflag:=true else ctrlflag:=false;
c:=chr(key and 255);
if (c=#0) and gstick.present then begin
 pollJoyStick;
 with gstick do begin
  dx:=x-centerx; dy:=y-centery;
  if abs(dx)>abs(dy) then begin
   if dx>joystvx then c:=#3 else if dx<-joystvx then c:=#4;
   end
  else begin
   if dy>joystvy then c:=#2 else if dy<-joystvy then c:=#1;
   end;
  if button1 then c:=#13;
  ctrlflag:=button2;
 end;
 end;
getinput:=c;
end;



procedure leverror(n:integer;s:string);
begin
exitptr;
writeln; writeln;
writeln('Error in load_level');
writeln('Line ',n);
writeln(s); halt(1);
end;



function fload_level(s:string):plevel;
var f:text;
    p1,p2,p3:plevel;
    dta:array[0..50] of string; b:byte;
    index,ndiam,diam,size,i,j,pos,x,y:integer; ln:word;
    foundplayer:boolean;
begin
fload_level:=nil; p1:=nil; p2:=nil; p3:=nil; ln:=0;
foundplayer:=false;
assign(f,s); reset(f);
if ioresult<>0 then error('unable to open level data file');
while not eof(f) do begin
 p2:=alloc(sizeof(tlevel)); if p2=nil then exit;
 readln(f,s); inc(ln);
 if s[1]='*' then begin
  p2^.enable:=1; s:=copy(s,2,255); end else p2^.enable:=0;
 p2^.name:=s;
 readln(f,s); inc(ln); val(s,p2^.timer,index);
 if index<>0 then leverror(ln,'unreadable timer value');
 readln(f,s); val(s,ndiam,index);
 if index<>0 then
  leverror(ln,'number of diamonds unknown');
 size:=0; diam:=0; index:=-1; x:=0;
 repeat
  readln(f,s); inc(ln);
  if s[1]<>'@' then begin
   index:=index+1;
   if index>50 then leverror(ln,'level too large');
   for i:=1 to length(s) do begin
    s[i]:=upcase(s[i]);
    if s[i]='S' then foundplayer:=true;
    if s[i]='*' then inc(diam);
    end;
    dta[index]:=s; inc(size,length(s));
   if length(s)>x then x:=length(s);
   end;
 until s[1]='@';
 if not foundplayer then leverror(ln,'Player start position not found');
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





procedure init;
var i:integer; c:char; s:string; p,userlev:plevel;
begin
clrscr; 
textcolor(White); textbackground(Blue);
write('                          BASH Version 1.0');
clreol; writeln;
textcolor(LightGray); textbackground(Black);
writeln; writeln;
writeln('(c) 1994 Hilmar Buchta');
writeln;
writeln('**********************************************************************');
writeln(' This is a beta testversion of BASH');
writeln(' Hit any key to continue');
writeln('**********************************************************************');
readkey;
inithandler;
mydir:=fexpand(paramstr(0)); i:=length(mydir);
while mydir[i]<>'\' do dec(i);
mydir:=copy(mydir,1,i-1);
color:=10;
initressource(mydir+'\bash.res');
writeln('loading bitmaps...');
for i:=0 to maxbitindex do bitm[i]:=load_bitmap(bitmaps[i]);
writeln('loading levels...');
all_level:=load_level(1);
textstyle.memptr:=load_font(1);
if paramcount>0 then begin
 writeln('loading user level from "',paramstr(1),'"');
 userlev:=fload_level(paramstr(1));
 end else userlev:=nil;
maxlevelintern:=0; p:=all_level;
while p<>nil do
 begin
{$IFDEF DEBUGMODE}
  p^.enable:=1;
{$ENDIF}
  inc(maxlevelintern); p:=p^.next;
 end;
p:=all_level; for i:=1 to maxlevelintern-1 do p:=p^.next;
p^.next:=userlev;
maxlevel:=0; p:=all_level;
{maxlevel neu ausrechnen}
while p<>nil do begin inc(maxlevel); p:=p^.next; end;
all_level^.enable:=1;
writeln;
{if not add_device(new(psndblast,init)) then}
 add_device(new(psndintern,init));
if TestJoystick then begin
 writeln('Joystick detected');
 writeln('Center joystick and press [SPACE]');
 writeln('press [ESC] to disable joystick');
 repeat
  c:=chr(scankey and 255);
  if c=' ' then begin CenterJoystick; break; end;
  if c=#27 then begin gstick.present:=false; break; end;
 until 1=0;
 oldbutton2:=false;
 end;
mainpalette:=load_palette(1);
snd:=sounddrvs[1];
snddrvnum:=1;
gamesolved:=false;
end;




function findbitmap(x,y:integer):integer;
var k:integer; b:byte;
begin
if (x<0) or (x>=lev.x) or (y<0) or (y>=lev.y) then begin
 findbitmap:=id_wall1; exit; end;
b:=lev.data^[x+y*lev.x];
case b of
{ ord(' '): k:=id_blank;
 ord('X'): k:=id_brick;}
 ord(':'): k:=id_wall1;
 ord('.') : k:=id_space;
 ord('E') : k:=id_exit;
 ord('O'),ord('P')
          : k:=id_stone;
 ord('S') : k:=id_player;
 ord('*'),ord('*')+1
          : k:=id_diamond;
 ord('-') : k:=id_brick2;
 ord('=') : k:=id_converter;
 ord('U') : k:=id_clock;
 ord('B'),ord('C') : k:=id_bomb;
 else begin
  if (b>=ord('1')) and (b<=ord('4')) then k:=id_monster
  else if (b>=ord('5')) and (b<=ord('8')) then k:=id_monster2
  else if (b>=ord('!')) and (b<=ord(')')) then k:=b-ord('!')+id_wall2
  else if (b>=ord('V')) and (b<=ord(']')) then k:=b-ord('V')+id_wallmove
  else k:=id_blank;
  end;
 end;
findbitmap:=k;
end;


procedure clip16pattern(x,y,pos,dx,dy:integer; bitm:pbuffer);
var dx1,dy1:integer; xdim:^word; line,pel:word;
begin
xdim:=pointer(bitm);
if (x>=320) or (y>=200) or (x+dx<=0) or (y+dy<=0) then exit;
dx1:=16; dy1:=16;
if x<0 then begin  inc(dx1,x); dec(pos,x); x:=0; end;
if x>304 then dec(dx1,x-304);
if y<0 then begin  inc(dy1,y); inc(pos,-y*xdim^); y:=0; end;
if y>184 then dec(dy1,y-184);
if dx1>dx then dx1:=dx;
if dy1>dy then dy1:=dy;
line:=y*82+x shr 2;
pel:=x and 3;
if (dx1>0) and (dy1>0) then putsubimage(line,pel,pos,dx1,dy1,bitm);
end;


procedure clipbitmap(x,y,pos,dx,dy:integer; bitm:pbuffer);
var dx1,dy1:integer; line,pel:word; xdim,ydim:word;
begin
if (x>=320) or (y>=200) or (x+dx<=0) or (y+dy<=0) then exit;
xdim:=bitm^[0]+256*bitm^[1];
ydim:=bitm^[2]+256*bitm^[3];
dx1:=xdim; dy1:=ydim;
if x<0 then begin  inc(dx1,x); dec(pos,x); x:=0; end;
if x>304 then dec(dx1,x-304);
if y<0 then begin  inc(dy1,y); inc(pos,-y*xdim); y:=0; end;
if y>184 then dec(dy1,y-184);
if dx1>dx then dx1:=dx;
if dy1>dy then dy1:=dy;
line:=y*82+x shr 2;
pel:=x and 3;
if (dx1>0) and (dy1>0) then putsubimage(line,pel,pos,dx1,dy1,bitm);
end;

procedure setupsplitscreen(lines:word);
var lnlow,lnhigh:byte;
begin
lnlow:=lo(400-2*lines); lnhigh:=hi(400-2*lines);
asm
  mov dx, 3D4h    { CRTC: Maximum Scan Line Register }
  mov al, 9h      { Bit 6 is Bit 9 of the Line Compare Register }
  out dx, al      { Default of Line Compare number is 1023 }

  inc dx          { This reg is 41h so bit 6 is the 4 so just 1h }
  mov al, lnhigh  { Line compare number is default 1023 we want }
  out dx, al      { to set it to 400 (lines) - 64 (32 (status bar }
                  { length) * 2 (double for 200 lines)) = 336 }

  dec dx          { CRTC: Line Compare Register }
  mov al, 18h     { Bit 8 is already set to 1 so 256 + 80 = 336 }
  out dx, al      { This will display the first 32 lines at 0A000:0000 }

  inc dx          { at the bottom of the screen.  So the screen }
  mov al, lnlow   { no matter where the display start address it }
  out dx, al      { will keep the status bar stationary. }

  { turn on split-screen pel pan supress: }
  mov  dx,03dah
  in   al,dx             { Reset the AC Index/Data toggle to index state }
  mov  al,10h+20h        { Bit 5 set to prevent screen blanking }
  mov  dx,03c0h          { Point AC to Index/Data register }
  out  dx,al
  inc  dx                { Point to AC Data reg (for reads only) }
  in   al,dx             { Get the current AC Mode Control reg }
  or   al,20h            { Enable split scrn Pel panning suppress. }
  dec  dx                { Point to AC Index/Data reg (for writes only) }
  out  dx,al             { Write the new AC Mode Control setting }
 end;
end;



procedure pan(dx,dy,count:integer);
var i,t0,t1:integer; page:byte; p:pointer; xdim:^word;
    xofs,yofs:word;
begin
scroll(dx+dy*328); xofs:=count*dx; yofs:=count*dy;
case dx of
   1:begin t1:=(count+8) and 15; t0:=(count+8) shr 4;
     for i:=0 to 12 do
     clip16pattern(319,vid_y_ofs-yofs+i*16,t1,1,16,
       bitm[findbitmap(20+t0+screen_x,i+screen_y)]);
     end;
  -1:begin t1:=(count+8) and 15; t0:=(count+8) shr 4;
     for i:=0 to 12 do
     clip16pattern(0,vid_y_ofs-yofs+i*16,15-t1,1,16,
      bitm[findbitmap(screen_x-t0,i+screen_y)]);
     end;
  end;
case dy of
  1:begin t1:=(count+8-vid_y_ofs) and 15; t0:=(count+8-vid_y_ofs) shr 4;
     for i:=0 to 20 do begin
      p:=bitm[findbitmap(screen_x+i-xofs,screen_y+12+t0)]; xdim:=pointer(p);
      clip16pattern(-8+i*16,199,xdim^*t1,16,1,p);
      end;
     end;
 -1:begin t1:=(count+16+vid_y_ofs) and 15; t0:=(count+16+vid_y_ofs) shr 4;
     for i:=0 to 20 do begin
      p:=bitm[findbitmap(screen_x+i-xofs,screen_y-t0)]; xdim:=pointer(p);
      clip16pattern(-8+i*16,0,xdim^*(15-t1),16,1,p);
      end;
     end;
  end;
end;


procedure updatestatusline_diam;
var temp1:longint; temp2:word; temp3:word; s:string;
begin
temp1:=vidadr; vidadr:=0;
temp2:=vidline; vidline:=0;
temp3:=vidpel; vidpel:=0;
textstyle.color:=70; textstyle.colorinc:=1;
clipbitmap(13,4,4*320+13,24,8,bitm[id_statusline]);
str(neededdiam:3,s);
outtextxy(13,4,s);
vidadr:=temp1; vidline:=temp2; vidpel:=temp3;
end;

procedure updatestatusline_timer;
var t,temp1:longint; temp2:word; temp3:word; s,s1:string;
begin
temp1:=vidadr; vidadr:=0;
temp2:=vidline; vidline:=0;
temp3:=vidpel; vidpel:=0;
textstyle.color:=70; textstyle.colorinc:=1;
clipbitmap(275,4,4*320+275,5*8,8,bitm[id_statusline]);
t:=abs(timer);
str(t div 60,s); if length(s)<2 then s:='0'+s;
str(t mod 60,s1); if length(s1)<2 then s1:='0'+s1;
if timer<0 then begin textstyle.color:=12; textstyle.colorinc:=0; end;
outtextxy(275,4,s+':'+s1);
vidadr:=temp1; vidline:=temp2; vidpel:=temp3;
end;

procedure updatestatusline_levelname(s:string);
var temp1:longint; temp2:word; temp3:word;
begin
temp1:=vidadr; vidadr:=0;
temp2:=vidline; vidline:=0;
temp3:=vidpel; vidpel:=0;
clipbitmap(60,4,4*320+60,25*8,8,bitm[id_statusline]);
outtextxy(60,4,s);
vidadr:=temp1; vidline:=temp2; vidpel:=temp3;
end;


procedure updatestatusline;
var temp1:longint; temp2:word; temp3:word;
begin
temp1:=vidadr; vidadr:=0;
temp2:=vidline; vidline:=0;
temp3:=vidpel; vidpel:=0;
clipbitmap(0,0,0,320,20,bitm[id_statusline]);
vidadr:=temp1; vidline:=temp2; vidpel:=temp3;
textstyle.color:=70; textstyle.colorinc:=1;
updatestatusline_levelname(lev.name);
updatestatusline_diam;
updatestatusline_timer;
end;

procedure inittimer;
var w1,w2,w3,w4:word; w:integer;
begin
gettime(w1,w2,w3,w4);
oldtimersec:=w3;
end;



procedure showplayfield;
var i,j:integer;
begin
for i:=0 to 20 do
 for j:=0 to 12 do
  clip16pattern(-8+i shl 4,vid_y_ofs+j shl 4,0,16,16,
   bitm[findbitmap(i+screen_x,j+screen_y)]);
end;

procedure buildplayfield;
var
 i,j,k:integer; b:byte;
 dx,dy,panval,count:integer;
begin
player_x:=0; player_y:=0; j:=0; levx:=lev.x; levy:=lev.y;
neededdiam:=lev.diam;
for i:=0 to lev.x-1 do for j:=0 to lev.y-1 do
 if (lev.data^[i+j*lev.x]=ord('S')) then begin
  player_x:=i; player_y:=j; end;
if (player_x=0) or (player_y=0) then exit; {Keine Startposition}
screen_x:=player_x-10; if screen_x<0 then screen_x:=-1;
if screen_x>levx-20 then screen_x:=levx-20;
screen_y:=player_y-6; if screen_y<0 then screen_y:=0;
if screen_y>levy-11 then screen_y:=levy-11;
if levx<20 then screen_x:=-10+levx shr 1;
if levy<12 then screen_y:=-6+levy shr 1;
showplayfield;
updatestatusline;
end;





procedure add(x1,y1,dx1,dy1,tp1,action1:integer;id1:char);
begin
if actptr>=maxactlst then error('internal: actlst overflow');
lev.data^[x1+y1*levx]:=32 or 128;
lev.data^[x1+dx1+levx*(y1+dy1)]:=ord(id1) or 128;
if (x1>=screen_x-2) and (x1<=screen_x+22) and (y1>=screen_y-2) and
 (y1<=screen_y+13) then begin
   inc(actptr);
   with (actlst[actptr]) do begin
    x:=x1; y:=y1; dx:=dx1; dy:=dy1; tp:=tp1; id:=id1; action:=action1;
   end;
  end;
end;


procedure addexplode1(x1,y1:integer);
{ FÅgt eine Explosion hinzu }
var c:byte; tp1:integer;
begin
{if explodeptr>maxexplst then error('internal: explodelst overflow');}
if explodeptr>=maxexplst then exit;
inc(explodeptr1);
c:=lev.data^[x1+y1*levx];
{lev.data^[x1+y1*levx]:=32+128;}
if (c>=ord('5')) and (c<=ord('8')) then tp1:=1 else tp1:=0;
with explist1[explodeptr1] do begin x:=x1; y:=y1; tp:=tp1; end;
end;

procedure addexplode(x1,y1:integer);
{ FÅgt eine Explosion hinzu }
var c:byte; tp1:integer;
begin
if explodeptr>maxexplst then error('internal: explodelst overflow');
snd^.setsfx(sn_explode);
inc(explodeptr);
c:=lev.data^[x1+y1*levx];
lev.data^[x1+y1*levx]:=32+128;
if (c>=ord('5')) and (c<=ord('8')) then tp1:=1 else tp1:=0;
with explist[explodeptr] do begin x:=x1; y:=y1; tp:=tp1; end;
c:=lev.data^[x1-1+(y1-1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1-1,y1-1);
c:=lev.data^[x1+(y1-1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1,y1-1);
c:=lev.data^[x1+1+(y1-1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1+1,y1-1);
c:=lev.data^[x1-1+y1*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1-1,y1);
c:=lev.data^[x1+1+y1*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1+1,y1);
c:=lev.data^[x1-1+(y1+1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1-1,y1+1);
c:=lev.data^[x1+(y1+1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1,y1+1);
c:=lev.data^[x1+1+(y1+1)*levx];
if (c=ord('B')) or (c=ord('C')) then addexplode1(x1+1,y1+1);
end;


procedure destroy(i:integer);
begin
if status=0 then begin
 status:=i; noactioncounter:=0;
 end;
end;


procedure checkexplode;
{ Entfernt die EintrÑge aus der actlst, die durch Explosionen zerstîrt
  wurden.}
var i,j:integer; xmin,ymin,xmax,ymax,extype:integer; c,c1:char;
begin
for j:=0 to explodeptr do begin
 xmin:=explist[j].x-1; xmax:=explist[j].x+1;
 ymin:=explist[j].y-1; ymax:=explist[j].y+1;
 for i:=0 to actptr do begin
 if ((actlst[i].x>=xmin) and (actlst[i].x<=xmax) and
    (actlst[i].y>=ymin) and (actlst[i].y<=ymax))
  then begin actlst[i]:=actlst[actptr]; dec(actptr); end;
  end;
 if (player_x>=xmin) and (player_x<=xmax) and
    (player_y>=ymin) and (player_y<=ymax) and (status<>3) then
     destroy(3);
 end;
for i:=0 to explodeptr do with explist[i] do begin
 if tp=0 then begin c1:='@'; extype:=id_explode; end
   else begin c1:='~'; extype:=id_diamond; end;
 c:=chr(lev.data^[x-1+levx*(y-1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x-1,y-1,0,0,extype,1,c1);
 c:=chr(lev.data^[x  +levx*(y-1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x  ,y-1,0,0,extype,1,c1);
 c:=chr(lev.data^[x+1+levx*(y-1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x+1,y-1,0,0,extype,1,c1);
 c:=chr(lev.data^[x-1+levx*y] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x-1,y  ,0,0,extype,1,c1);
 c:=chr(lev.data^[x  +levx*y] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x  ,y  ,0,0,extype,1,c1);
 c:=chr(lev.data^[x+1+levx*y] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x+1,y  ,0,0,extype,1,c1);
 c:=chr(lev.data^[x-1+levx*(y+1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x-1,y+1,0,0,extype,1,c1);
 c:=chr(lev.data^[x  +levx*(y+1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x  ,y+1,0,0,extype,1,c1);
 c:=chr(lev.data^[x+1+levx*(y+1)] and 127);
 if (c<>'X') and (c<>'E') and (c<>'@') then add(x+1,y+1,0,0,extype,1,c1);
 end;
end;




procedure update;
{
Aktualisiert das Spielfeld in lev.data^. VerÑnderungen, die au·erhalb
des sichtbaren Spielfeldes liegen werden direkt durchgefÅhrt. Solche, die
innerhalb des sichtbaren Bereichs liegen, werden in der Liste actlst ver-
merkt und die ursprÅnglichen EintrÑge werden gelîscht.
}
var i,j,k,k1,k2,t,t1,t2,f1,f2,mx,my,base,tp,action:integer;
    c,c1:char;
    dc:byte;
begin
k:=explodeptr1;
move(explist1,tmpexp,sizeof(tmpexp));
explodeptr1:=-1;
for j:=0 to k do
 with tmpexp[j] do addexplode(x,y);
for j:=0 to levy-1 do for i:=0 to levx-1 do begin
 k:=i+j*levx;
 c:=chr(lev.data^[k]);
 if (c=' ') or (c='X') or (c='-') then continue;
 k2:=0;

 { **** STEINE, DIAMANTEN UND BOMBEN **** }
 { Neue Bewegung auslîsen }
 if (c='O') then k2:=id_stone else if c='*' then k2:=id_diamond else
  if c='B' then k2:=id_bomb;
 if k2<>0 then begin dc:=lev.data^[k+levx];
  dc:=lev.data^[k+levx];
  if dc=32 then add(i,j,0,1,k2,0,chr(ord(c)+1)) else
  if (k2=id_stone) and (dc=ord('=')) and (lev.data^[k+levx shl 1]=32)
   then add(i,j,0,1,id_stone,2,chr(ord('=')+1)) else
   if (k2=id_diamond) and (random(10)=1)
    then add(i,j,0,0,id_diamond,1,c) else
  if (dc<>ord('.')) and (dc and 127<>ord('S')) and (dc and 128=0)
   then begin
    if (lev.data^[k+levx-1]=32) and (lev.data^[k-1]=32) then
     add(i,j,-1,0,k2,0,chr(ord(c)+1)) else
    if (lev.data^[k+levx+1]=32) and (lev.data^[k+1]=32) then
     add(i,j,+1,0,k2,0,chr(ord(c)+1));
   end;
  continue;
  end;

 { **** STEINE UND DIAMANTEN BEWEGEN **** }
 k2:=0;
 if c=chr((ord('O')+1)) then k2:=id_stone else if
    c=chr((ord('*')+1)) then k2:=id_diamond;
 if k2<>0  then begin dc:=lev.data^[k+levx];
   action:=0;
   if (k2=id_diamond) and (random(10)=1) then action:=1;
   if (dc=32) then begin
      add(i,j,0,1,k2,action,c);
      continue;
      end;
   snd^.setsfx(sn_hit);
   if ((dc and 127 >=ord('1')) and ((dc and 127) <=ord('8')))
     or (dc and 127=ord('S')) then
      addexplode(i,j+1)
   else if (k2=id_stone) and (dc=ord('=')) and
    (lev.data^[k+2*levx]=32) then
    add(i,j,0,1,id_stone,2,chr(ord('=')+1))
   else if (dc<>ord('.')) and (dc and 127<>ord('S')) and (dc and 128=0)
        then begin
        if (lev.data^[k-1]=32) and (lev.data^[k-1+levx]=32) then
         add(i,j,-1,0,k2,action,c)
       else if (lev.data^[k+1]=32) and (lev.data^[k+1+levx]=32) then
         add(i,j,1,0,k2,action,c)
       else lev.data^[k]:=ord(c)-1;
       end
      else lev.data^[k]:=ord(c)-1;
   continue;
   end;

 {**** KONVERTER ****}
 if (c=chr(ord('=')+1)) and (lev.data^[k+levx]=32) then begin
  add(i,j,0,0,id_converter,4,chr(ord('=')+2));
  continue;
  end;
 if (c=chr(ord('=')+2)) and (lev.data^[k+levx]=32) then begin
  add(i,j,0,1,id_diamond,3,chr(ord('*')+1));
  lev.data^[k]:=ord('='); { Konverter neu erzeugen }
  continue;
  end;
 if (c='W') then add(i,j,0,0,id_wallconvert,0,'W');
 {**** MONSTER ****}
 if (c>='1') and (c<='8') then begin  { Monster }
   dc:=lev.data^[k-levx] and 127;
   if (dc=ord('P')) or (dc=ord('*')+1) or (dc=ord('B')+1) then
    begin addexplode(i,j); continue; end;
    t1:=ord(c)-ord('1');
     if t1>3 then begin base:=ord('5'); dec(t1,4); tp:=id_monster2; end
       else begin base:=ord('1'); tp:=id_monster; end;
    f1:=dir[t1,0]; f2:=dir[t1,1];
    for k2:=-1 to 1 do for k1:=-1 to 1 do begin
     dc:=lev.data^[k+k1*(f1+f2*levx)+k2*(f2-f1*levx)];
     if (dc>=ord('1')) and (dc<=ord('8')) then dc:=ord('1');
     mons[(-k2+1)+(-k1+1)*3]:=dc;
     end;
   if (mons[3] =32) and
     (mons[6] and 127 <>32) and (mons[6] and 127<>ord('1')) then
      begin mx:=f2; my:=-f1; c:=chr((t1+1) and 3+base) end
   else
   if (mons[3] =32) and (mons[6] =32) and (mons[5] and 127=32)
    and (mons[8] and 127<>32) and (mons[8] and 127 <>ord('1')) then
      begin mx:=-f2; my:=f1; c:=chr((t1+3) and 3+base) end
   else
   if (mons[1]=32) then begin mx:=f1; my:=f2; end
   else
   if (mons[1] and 127=ord('S')) then begin
     mx:=f1; my:=f2; addexplode(i+f1,j+f2) end else
   if (mons[3]=32) then begin mx:=f2; my:=-f1; c:=chr((t1+1) and 3+base) end
   else
   if (mons[5]=32) then begin mx:=-f2; my:=f1; c:=chr((t1+3) and 3+base) end
   else
   if (mons[7]=32) then begin mx:=-f1; my:=-f2; c:=chr((t1+2) and 3+base) end
   else begin mx:=0; my:=0; c:=chr(base); end;
   add(i,j,mx,my,tp,0,c);
   k1:=k+mx+(my-1)*levx;
   if lev.data^[k1] and 127=ord('S') then
    begin destroy(4); continue; end;
   inc(k1,levx-1);
   if lev.data^[k1] and 127=ord('S') then
    begin destroy(4); continue; end;
   inc(k1,2);
   if lev.data^[k1] and 127=ord('S') then
    begin destroy(4); continue; end;
   inc(k1,levx-1);
   if lev.data^[k1] and 127=ord('S') then
    begin destroy(4); continue; end;
   continue;
   end;

 {**** UHREN ****}
 if (c='U') and (random(8)=1) then begin
  add(i,j,0,0,id_clock,1,c);
  continue; end;

 {**** BOMBEN ****}
 if c=chr((ord('B')+1) and 127) then begin
  if lev.data^[k+levx]=32 then add(i,j,0,1,id_bomb,0,c)
   else addexplode(i,j);
  continue;
  end; { von if (c='... }
 end; { der for-Schleifen }
end;



procedure checktimer;
var w1,w2,w3,w4:word; w:integer;
begin
gettime(w1,w2,w3,w4);
if w3<>oldtimersec then begin
 w:=w3-oldtimersec; if w<0 then w:=w+60;
 dec(timer,w);
 updatestatusline_timer;
 oldtimersec:=w3;
 end;
end;



procedure blinkscreen;
{ Hellt kurz den Bildschirm auf, um anzuzeigen, da· alle Diamanten
 aufgesammelt wurden }
var p1,p2:array[0..770] of byte; i:integer;
begin
getpalette(@p1);
for i:=0 to 767 do p2[i]:=63;
setpalette(@p2);
delay(50);
setpalette(@p1);
end;




procedure bar3d(x,y,cdx,cdy:word;col:byte);
begin
bar(x,y,cdx,cdy,col);
hline(x,y,cdx,15); hline(x,y+cdy-1,cdx,col+1);
vline(x,y,cdy,15); vline(x+cdx-1,y,cdy,col+1);
end;


procedure errorbox(s:string);
var l,x1:integer;
begin
l:=length(s)*8+20; x1:=160-(l shr 1);
bar3d(x1,50,l,30,80);
textstyle.color:=32; textstyle.colorinc:=1;
outtextxy(x1+10,60,s);
waitkeyrelease; repeat until getinput<>#0;
end;



procedure eatdiamond(i:integer);
var k:integer;
begin
if neededdiam<>1 then snd^.setsfx(sn_takediam)
 else snd^.setsfx(sn_alldiam);
if (neededdiam>0) then begin
 dec(neededdiam); updatestatusline_diam;
end;
{ Blinkenden Diamanten aus Aktionsliste lîschen: }
for k:=0 to actptr do with actlst[k] do begin
 if (action=1) and (x+levx*y=i) then begin
 actlst[k]:=actlst[actptr]; dec(actptr); break; end;
end;
end;


procedure play;
var
  pdx,pdy,                  { Bewegung der Spielfigur }
  sdx,sdy,                  { Scrollbewegung des Bildschirms }
  count,                    { =1 bis 20 zÑhlt die Zwischenschritte }
  noactionbreak,
  i,j,k,tx,ty,t,ysize,id,xpush,dir,olddir
   :integer;
  c:char;                   { Tastatureingabe }
  b:byte;
  bit_ofs:word;
  walk,paction:boolean;
  pal:array[0..770] of byte; { Palette }

label 1;
begin
explodeptr1:=-1; olddir:=0;
if neededdiam=0 then neededdiam:=-1; xpush:=0;
noactioncounter:=0; status:=0; player_bitofs:=0; inittimer;
getpalette(@pal); noactionbreak:=6;
repeat snd^.initpoll;
explodeptr:=-1;
if xpush>0 then dec(xpush);
pdx:=0; pdy:=0; paction:=false; sdx:=0; sdy:=0;  inc(noactioncounter);
walk:=false; actptr:=-1;
{ ********** Bearbeitung der Spielereingabe *********** }
if status=4 then begin
 status:=3; addexplode(player_x,player_y);
 end else if status=0 then begin
  b:=lev.data^[player_x+(player_y-1)*levx] and 127;
  if (b=ord('P')) or (b=ord('C')) or (b=ord('*')+1) then begin
   addexplode(player_x,player_y); status:=2; end;
  end;
c:=getinput;
if (c<>#0) and (status=0) then begin
 case c of
  #3: begin pdx:=1; pdy:=0; player_bitofs:=32*64; noactioncounter:=0;end;
  #4: begin pdx:=-1; pdy:=0; player_bitofs:=16*64;noactioncounter:=0; end;
  #2: begin pdx:=0; pdy:=1; player_bitofs:=64*64; noactioncounter:=0;end;
  #1: begin pdx:=0; pdy:=-1; player_bitofs:=48*64; noactioncounter:=0; end;
 #27: begin status:=2; noactioncounter:=3;
      clip16pattern(-8+(player_x+pdx-screen_x) shl 4,
           vid_y_ofs+(player_y+pdy-screen_y) shl 4,
           0,16,16,bitm[id_angryplayer]);
      clip16pattern(-8+(player_x+pdx-screen_x) shl 4,
           vid_y_ofs+(player_y+pdy-screen_y-1) shl 4,
           0,16,16,bitm[id_shit]);
      end;
 #32: begin
      textstyle.color:=12; textstyle.colorinc:=0;
      updatestatusline_levelname('***  PAUSE  ***');
      waitkeyrelease;
      repeat until getinput<>#0;
      textstyle.color:=70; textstyle.colorinc:=1;
      updatestatusline_levelname(lev.name);
      waitkeyrelease;
      showplayfield; inittimer; end;
  end;
 dir:=pdx+pdy shl 1; if olddir<>dir then xpush:=0;
 olddir:=dir;
 walk:=not ctrlflag;
 i:=player_x+pdx+(player_y+pdy)*levx;
 b:=lev.data^[i];
 if walk or (xpush=0) then case chr(b) of
  ' ','.'
   : ;
  '*','+'
   : eatdiamond(i);
  'E'
   : if neededdiam<=0 then begin status:=1;
     bit_ofs:=0;
     for count:=0 to 3 do begin
      for i:=0 to 3 do verticalretrace;
      clip16pattern(-8+(player_x+pdx-screen_x) shl 4,
           vid_y_ofs+(player_y+pdy-screen_y) shl 4,
           bit_ofs,16,16,bitm[id_exit]);
      inc(bit_ofs,16);
      end;
     exit; end
     else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
  'U'
   : begin inc(timer,20); updatestatusline_timer; end;
  'O','P'
   : if (pdy=0) and (xpush=0) and
     (lev.data^[player_x+pdx shl 1+levx*player_y]=32) then begin
      add(player_x+pdx,player_y,pdx,0,id_stone,0,chr(b));
      inc(player_bitofs,64*64); xpush:=2;
     end else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
  'B','C'
   : if (pdy=0) and (xpush=0) and
     (lev.data^[player_x+pdx shl 1+levx*player_y]=32) then begin
      add(player_x+pdx,player_y,pdx,0,id_bomb,0,chr(b));
      inc(player_bitofs,64*64); xpush:=2;
     end else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
  'V':begin
      b:=lev.data^[player_x+pdx shl 1+levx*(player_y+pdy shl 1)];
      if (xpush=0) and (b=32) or (b=ord('W')) then begin
      if b=ord('W') then
       {Verschiebeblock in Diamant verwandeln}
       add(player_x+pdx,player_y+pdy,pdx,pdy,id_wallmove,1,'*')
       else
      add(player_x+pdx,player_y+pdy,pdx,pdy,id_wallmove,0,'V');
      if pdy=0 then inc(player_bitofs,64*64);
      xpush:=2;
      end else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
      end;
  else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
  end else begin pdx:=0; pdy:=0; xpush:=0; goto 1; end;
 if not walk then begin
  { Aktion aus dem Stand heraus }
  xpush:=2;
  i:=player_x+pdx+(player_y+pdy)*levx;
  clip16pattern(-8+(player_x+pdx-screen_x) shl 4,
           vid_y_ofs+(player_y+pdy-screen_y) shl 4,
           0,16,16,bitm[id_blank]);
  clip16pattern(-8+(player_x-screen_x) shl 4,
           vid_y_ofs+(player_y-screen_y) shl 4,
           player_bitofs,16,16,bitm[id_player]);
  lev.data^[i]:=32+128;
 end
 else begin
 { Aktion aus der Bewegung heraus }
 if xpush<2 then xpush:=0;
 case pdx of
   1: if (levx-screen_x>20) and (player_x-screen_x>=9)
      then sdx:=pdx;
  -1: if (screen_x>=0) and (player_x-screen_x<=9)
      then sdx:=pdx;
  end;
  case pdy of
   1: if (levy-screen_y>11) and (player_y-screen_y>=6)
      then sdy:=pdy;
  -1: if (screen_y>=0) and (player_y-screen_y<=6)
      then sdy:=pdy;
  end;
 add(player_x,player_y,pdx,pdy,id_player,0,'S');
 snd^.setsfx(sn_walk);
 end;
 end { Ende der Tastatureingabe }
 else xpush:=0;
1:
update;
checktimer; checkexplode;
for i:=0 to levx*levy-1 do begin
 c:=chr(lev.data^[i] and 127);
 if c='@' then lev.data^[i]:=32 else
 if c='~' then lev.data^[i]:=ord('*');
 end;
{$IFDEF DEBUGMODE}
{if status<>2 then status:=0;}
{$ENDIF}
if (status=0) and (noactioncounter>noactionbreak) then begin
  add(player_x,player_y,0,0,id_player,0,'S');
  player_bitofs:=0;
  noactionbreak:=4+random(6); noactioncounter:=0;
  end;
{ ********** Darstellen eines Zuges (in 16 TeilzÅgen) *********** }
for count:=1 to 16 do begin
 verticalretrace;
 if ((status=3) or (status=2)) and (noactioncounter>4) and
  (count and 2=0) then begin
  for i:=0 to 768 do if pal[i]>0 then dec(pal[i]);
  setpalette(@pal);
  if noactioncounter>13 then exit;
  end;

 if (sdx<>0) or (sdy<>0) then pan(sdx,sdy,count-1);
 for i:=0 to actptr do with actlst[i] do begin
  t:=tp;
  tx:=-8+(x-screen_x) shl 4+(dx-sdx)*count;
  ty:=vid_y_ofs+(y-screen_y) shl 4+(dy-sdy)*count;
  bit_ofs:=0; ysize:=16;
  case tp of
   id_player : bit_ofs:=player_bitofs+((count shr 2) and 3) shl 4;
   id_monster,id_monster2
             : bit_ofs:=((count shr 2) and 3) shl 4;
   id_diamond: if action=1 then bit_ofs:=((count shr 2) and 3) shl 4
               else
               if action=3 then
                begin ysize:=count; bit_ofs:=16*64-count shl 6;
                 ty:=vid_y_ofs+(1+y-screen_y) shl 4 -sdy*count;
                end;
   id_clock  : bit_ofs:=((count shr 2) and 3) shl 4;
   id_explode: if count<15 then bit_ofs:=(((count-1) shr 2) and 3) shl 4
                else t:=id_blank;
   id_stone  : if action=2 then ysize:=16-count;
   id_converter: if action=4 then bit_ofs:=((count shr 2) and 3) shl 4;
   id_wallmove: if action=1 then begin
                if count<15 then
                   bit_ofs:=64*16+(((count -1) shr 2) and 3) shl 4
                   else t:=id_diamond;
                end else bit_ofs:=((count shr 2) and 3) shl 4;
   id_wallconvert:
               bit_ofs:=((count shr 2) and 3) shl 4;
   end;
  case dx of
    1: clip16pattern(tx-1,ty,0,1,16,bitm[id_blank]);
   -1: clip16pattern(tx+16,ty,0,1,16,bitm[id_blank]);
    end;
  if action<>3 then case dy of
    1: clip16pattern(tx,ty-1,0,16,1,bitm[id_blank]);
   -1: clip16pattern(tx,ty+16,0,16,1,bitm[id_blank])
   end;
   clip16pattern(tx,ty,bit_ofs,16,ysize,bitm[t]);
  end;
  snd^.poll(count);
 end;
if walk then begin inc(player_x,pdx); inc(player_y,pdy); end;
inc(screen_x,sdx); inc(screen_y,sdy);
if neededdiam=0 then begin blinkscreen; dec(neededdiam); end;
for i:=0 to levx*levy-1 do lev.data^[i]:=lev.data^[i] and 127;
until (0=1);
end;






procedure effect_finish;
var i,xs,ys,dx,dy,x,y:integer;
begin
x:=320; y:=0; xs:=320 div 4; ys:=(200-16) div 4-1;
dx:=-4; dy:=0;
repeat
for i:=1 to xs do begin
 delay(1);
 clip16pattern(x,y,x and 15+(y and 15) shl 4,4,4,bitm[id_wall1]);
 inc(x,dx);
 end;
i:=dx; dx:=dy; dy:=-i;
for i:=1 to ys do begin
 delay(1);
 clip16pattern(x,y,x and 15+(y and 15) shl 4,4,4,bitm[id_wall1]);
 inc(y,dy);
 end;
i:=dx; dx:=dy; dy:=-i;
dec(xs,1); dec(ys,1);
until (xs<=0) and (ys<=0);
end;



procedure thatsall;
var p:pbuffer;
    pblank:array[0..770] of byte;
    i,j:integer; xdim,ydim:word;
begin
p:=load_bitmap(155);
for i:=15 downto 0 do begin
 setupsplitscreen(i);
 verticalretrace; verticalretrace; verticalretrace; end;
palfadeout;
for i:=0 to 770 do pblank[i]:=0;
if p<>nil then begin
 xdim:=p^[0]+256*p^[1];
 ydim:=p^[2]+256*p^[3];
 setpalette(@pblank);
 for i:=0 to 20 do for j:=0 to 12 do
 clip16pattern(i shl 4,j shl 4,0,16,16,bitm[id_wall1]);
 clipbitmap(160-xdim shr 1,100-ydim shr 1,0,320,200,p);
 palfadein(mainpalette);
 while getinput=#0 do ;
 palfadeout;
 disalloc(p);
 end;
end;



procedure playsinglelevel(lnum:integer);
var size:longint; i,j,pos:integer;
    pblank:array[0..770] of byte;
    p:plevel; b:byte; f:file;
label 1;
begin
if lnum>maxlevel then exit;
p:=all_level; for i:=1 to lnum do p:=p^.next;
if p^.enable=0 then exit;
centerscreen;
for i:=0 to 768 do pblank[i]:=0;
setpalette(@pblank);
size:=p^.x*p^.y;
lev:=p^; lev.data:=alloc(size);
pos:=0;
{ Level entpacken: }
for i:=0 to p^.packsize-1 do begin
 if pos>size then exit;
 b:=p^.data^[i];
 if (b and 128 <>0) then begin b:=b and 127;
  for j:=1 to b do begin lev.data^[pos]:=p^.data^[i+1]; inc(pos); end;
  inc(i,1);
  end else begin lev.data^[pos]:=b; inc(pos); end;
end;
timer:=p^.timer;
buildplayfield;
palfadein(mainpalette);
play;
if (status=1) then begin
 if timer>=0 then begin
 p^.enable:=2;
 if (p^.next<>nil) and (p^.next^.enable<>2) then p^.next^.enable:=1;
 { NÑchstes noch nicht geschaftes Spiel suchen }
 if p^.next<>nil then begin p:=p^.next; inc(mrk); end;
 while (p<>nil) and (p^.enable<>1) do
  begin p:=p^.next; inc(mrk); end;
 if p=nil then begin
  { Kein Spiel weiter hinten, nochmal von vorne suchen }
  mrk:=0; p:=all_level;
  while (p<>nil) and (p^.enable<>1) do
   begin p:=p^.next; inc(mrk); end;
  if p=nil then begin
   { Alle Level geschafft! }
   if not gamesolved then begin
    thatsall; gamesolved:=true; mrk:=0; goto 1;
   end;
   end;
  end;
 effect_finish;
 end else errorbox('Out of time')
 end;
1:
disalloc(lev.data);
if mrk>=maxlevel then mrk:=maxlevel-1;
end;


const save_ciffer:array[0..7] of byte =
 (49,1,196,199,59,252,121,17);

function get_file_choice(tp:string):integer;
var i,k,nf,ps,oldps:integer; f:file; s:string; c:char; keydown:boolean;
begin
setupsplitscreen(0); keydown:=false;
get_file_choice:=-1; nf:=0;
bar3d(60,20,200,90,7);
bar3d(60,115,200,63,7);
textstyle.color:=70; textstyle.colorinc:=1;
outtextxy(120-length(tp) shr 4,140,tp);
for k:=0 to 7 do begin
 str(k,s);
 assign(f,mydir+'\SAVEGAME.'+s); reset(f,1);
 if ioresult<>0 then begin
  textstyle.color:=8; textstyle.colorinc:=0;
  outtextxy(90,30+k*9,'[empty]');
  savegame_list[k]:=''
  end
  else
  begin
   blockread(f,savegame_list[k],20); close(f);
   for i:=0 to 20 do
    savegame_list[k,i]:=chr(ord(savegame_list[k,i]) xor save_ciffer[i and 7]);
    if savegame_list[k,0]>#18 then savegame_list[k,0]:=#18;
    if savegame_list[k,19]<>#42 then begin
     outtextxy(90,30+k*9,'[damaged]'); savegame_list[k]:='';
     end else begin
      textstyle.color:=70; textstyle.colorinc:=1;
      outtextxy(90,30+k*9,savegame_list[k]); inc(nf);
     end;
  end;
 end;
clipbitmap(70,30,0,16,9,bitm[id_arrow]); oldps:=0; ps:=0;
waitkeyrelease;
repeat
c:=getinput;
if c<>#0 then begin
 if not keydown then begin
 case c of
 #27   : exit;
 #1    : if ps>0 then dec(ps);
 #2    : if ps<7 then inc(ps);
 chr(k_pgup)
       : ps:=0;
 chr(k_pgdown)
       : ps:=7;
 #13   : begin get_file_choice:=ps; exit; end;
 end;
 keydown:=true;
 end;
end else keydown:=false;
if ps<>oldps then begin
 bar(70,30+oldps*9,10,9,7);
 clipbitmap(70,30+ps*9,0,16,9,bitm[id_arrow]);
 oldps:=ps;
 end;
until 1=0;
end;





function processinput(n:integer):integer;
var x,y:integer; s:string; c:char; keydown:boolean;
begin
processinput:=-1; { fÅr keine énderung, also Abbruch }
s:=savegame_list[n];
y:=30+n*9; x:=90+8*length(s);
textstyle.color:=40; textstyle.colorinc:=2;
bar(x,y,(18-length(s))*8,8,7); outtextxy(90,y,s);
vline(x,y,8,15);
waitkeyrelease; keydown:=false;
repeat
c:=getinput;
if (c<>#0) then begin
 if not keydown then begin
 case c of
 #27 : exit;
 #13 : begin savegame_list[n]:=s; processinput:=0; exit; end;
  #8 : if length(s)>0 then begin
       s:=copy(s,1,length(s)-1);
       dec(x,8); bar(x,y,9,8,7);
       vline(x,y,8,15);
       end;
 else if (c>=#32) and (c<=#126) and (length(s)<18) then begin
    s:=s+c; bar(x,y,1,8,7);
    outtextxy(x,y,c); inc(x,8);
    vline(x,y,8,15);
    end;
 end;
 keydown:=true;
 end;
 end else keydown:=false;
until 1=0;
end;


procedure savegame;
var i,n,bp:integer; f:file; s:string; b:array[0..1024] of byte;
    rand:byte; sum:word; bitpos:integer; p:plevel;
begin
randomize;
n:=get_file_choice('save game');
if n<0 then exit;
if processinput(n)<0 then exit;
move(savegame_list[n],b[0],19); bp:=19;
b[bp]:=42; inc(bp);
rand:=random(50);
b[bp]:=rand; inc(bp);
for i:=bp to bp+rand-1 do b[i]:=random(255);
inc(bp,rand);
b[bp]:=maxlevel; inc(bp);
p:=all_level;
while p<>nil do begin
 b[bp]:=p^.enable; inc(bp);
 p:=p^.next;
end;
b[bp]:=mrk; inc(bp);
rand:=random(50);
for i:=bp to bp+rand-1 do b[i]:=random(255);
inc(bp,rand);
sum:=0;
for i:=0 to bp-1 do begin
 sum:=sum+b[i]; b[i]:=b[i] xor save_ciffer[i and 7];
 end;
b[bp]:=hi(sum); b[bp+1]:=lo(sum); inc(bp,2);
str(n,s); assign(f,mydir+'\SAVEGAME.'+s); rewrite(f,1);
blockwrite(f,b[0],bp);
if ioresult<>0 then errorbox('Error saving game position');
close(f);
end;


function loadgame:integer;
var i,n,levels:integer; b:array[0..1024] of byte; s:string;
    f:file; sz:longint; sum,check:word; p:plevel;
begin
loadgame:=-1; {error in loadgame}
n:=get_file_choice('load game');
if n<0 then begin loadgame:=0; exit; end; { Abbruch }
if (savegame_list[n,0]=#0) then exit;
str(n,s); assign(f,mydir+'\SAVEGAME.'+s); reset(f,1);
sz:=filesize(f); if sz>1024 then sz:=1024;
blockread(f,b[0],sz);
close(f);
sum:=b[sz-1]+word(b[sz-2]) shl 8;
check:=0;
for i:=0 to sz-3 do begin
 b[i]:=b[i] xor save_ciffer[i and 7];
 check:=check+b[i];
 end;
if check<>sum then exit;
i:=21+b[20];
levels:=b[i]; inc(i);
p:=all_level;
for n:=0 to maxlevel-1 do begin
 if n>levels then p^.enable:=0 else
  begin
   p^.enable:=b[i]; inc(i);
  end;
 p:=p^.next;
 end;
mrk:=b[i];
if mrk>maxlevel-1 then mrk:=maxlevel-1;
loadgame:=0;
gamesolved:=false;
p:=all_level;
while (p<>nil) and (p^.enable=2) do p:=p^.next;
if p=nil then gamesolved:=true;
p:=all_level;
end;



function findlevel(i:integer):plevel;
var p:plevel; k:integer;
begin
p:=all_level;
for k:=1 to i-1 do begin
 if p=nil then break;
 p:=p^.next;
 end;
findlevel:=p;
end;



procedure show_level_box_entry(i:integer);
var s:string; var k:integer; p:plevel;
begin
p:=findlevel(i); if p=nil then exit;
str(i:2,s);
{ Farben 68, 72, 168, 164 }
if p^.enable=2 then
 begin textstyle.color:=72; textstyle.colorinc:=0; end
 else if p^.enable=1 then begin
  textstyle.color:=96;  textstyle.colorinc:=0;
  end
  else begin
   textstyle.color:=168; textstyle.colorinc:=0; end;
outtextxy(80,30+9*(i-top-1),s+'. '+copy(p^.name,1,18));
end;


procedure show_level_box;
begin
bar3d(60,20,200,90,7);
if top<0 then top:=0;
for j:=1 to 8 do show_level_box_entry(top+j);
clipbitmap(67,30+9*(mrk-top),0,10,9,bitm[id_arrow]);
end;


procedure show_select_screen;
begin
vid_y_ofs:=-4;
setupsplitscreen(16);
for i:=0 to 20 do for j:=0 to 12 do
 clip16pattern(i shl 4,j shl 4,0,16,16,bitm[id_wall1]);
setpalette(mainpalette);
tmp1:=vidline; tmp2:=vidpel;
bar3d(0,0,320,16,7);
textstyle.color:=65; textstyle.colorinc:=1;
outtextxy(110,4,'BASH V1.0');
bar3d(60,115,200,63,7);
textstyle.color:=32; textstyle.colorinc:=1;
outtextxy(90,120,#24#25);
outtextxy(70,129,'[ENTER]');
outtextxy(82,138,'L / S');
outtextxy(82,147,'[F1]');
outtextxy(82,156,'[F2]');
outtextxy(78,165,'[ESC]');
textstyle.color:=86; textstyle.colorinc:=1;
outtextxy(140,120,'choose level');
outtextxy(140,129,'play');
outtextxy(140,138,'load/save game');
outtextxy(140,147,'Help');
outtextxy(140,156,snd^.drvname);
outtextxy(140,165,'quit');
vidline:=0; vidpel:=0;
bar(0,0,328,15,8);
vidline:=tmp1; vidpel:=tmp2;
show_level_box;
strcount1:=0; strcount2:=0;
keydown:=false;
end;



procedure helpscreen;
var i:integer;
begin
setupsplitscreen(0);
bar3d(10,20,300,140,7);
textstyle.color:=8; textstyle.colorinc:=0;
outtextxy(80,30,'BASH Keyboard Control');
hline(160-50,40,100,1);
textstyle.color:=White;
outtextxy(30,50,#24#25#26#27'       to move the player');
outtextxy(30,59,'Ctrl+'#24#25#26#27'  to push');
outtextxy(30,68,'ESC        suicide');
outtextxy(30,77,'SPACE      pause game');
textstyle.color:=8; textstyle.colorinc:=0;
outtextxy(80,95,'BASH Joystick Control');
hline(160-50,105,100,1);
textstyle.color:=White;
outtextxy(30,115,'Use joystick to move player,');
outtextxy(30,124,'Button 2 together with stick to');
outtextxy(30,133,'push into specified direction');
waitkeyrelease;
while getinput=#0 do ;
setupsplitscreen(16);
end;


const banner:string=
  '+++ BASH V1.0 prerelease'+
  ' +++ game programming: Hilmar Buchta'
 +' +++ graphix and level design: Jan Smolczyk'
{+' +++ sound effects: Thorsten Engel'}
 +' +++ special thanks to Kris Arndt'
 +' +++                                    ';


procedure chooselevel;
var p:plevel; keycounter:word;
begin
keycounter:=0;
mrk:=0; top:=0;
show_select_screen;
imbuf1:=alloc(imagesize(0,0,324,15));
imbuf2:=alloc(imagesize(50,50,270,180));
repeat
verticalretrace;
{ Tastatureingabe }
c:=getinput;
if (c<>#0) then begin
 if not keydown then begin keycounter:=0;
 case c of
  #1 : if mrk>0 then begin
        if mrk<=top then begin
          getsubimage(30*82+19,1,22*8+4,7*9,imbuf2);
          putsubimage(30*82+19+9*82,1,0,22*8+4,7*9,imbuf2);
          bar(80,30,22*8+1,8,7);
          dec(top);
          show_level_box_entry(mrk);
          end
        else begin
         bar(67,30+9*(mrk-top),10,9,7);
         clipbitmap(67,30+9*(mrk-top-1),0,10,9,bitm[id_arrow]);
        end;
       dec(mrk);
      end;
  #2 : if mrk+1<maxlevel then begin
        if mrk>=top+7 then begin
          getsubimage(30*82+19+9*82,1,22*8+4,7*9,imbuf2);
          putsubimage(30*82+19,1,0,22*8+4,7*9,imbuf2);
          bar(80,30+7*9,22*8+1,8,7);
          inc(top);
          show_level_box_entry(mrk+2);
          end
        else begin
         bar(67,30+9*(mrk-top),10,9,7);
         clipbitmap(67,30+9*(mrk-top+1),0,10,9,bitm[id_arrow]);
        end;
       inc(mrk);
      end;
  #13 : begin
       p:=findlevel(mrk+1);
       if (p<>nil) and (p^.enable>0) then begin
        playsinglelevel(mrk);
        if mrk-top>7 then top:=mrk-7 else
         if mrk<top then top:=mrk;
        show_select_screen;
        waitkeyrelease;
        end;
       end;
  chr(k_pgup)
      : if mrk>0 then begin dec(top,7);
         if top<0 then begin mrk:=0; top:=0; end else dec(mrk,7);
         show_level_box;
         end;
  chr(k_pgdown)
      : if mrk<maxlevel-1 then begin inc(top,7);
         if top+9>=maxlevel then begin top:=maxlevel-8; mrk:=maxlevel-1; end
          else inc(mrk,7);
         show_level_box;
        end;
  'l','L':
        begin
           if loadgame<0 then
             errorbox('Error loading game position');
           top:=mrk-4; if top<0 then top:=0;
           show_select_screen;  waitkeyrelease;
           end;
  's','S':
         begin savegame; show_select_screen; waitkeyrelease; end;
  chr(k_f1): begin
        helpscreen;
        show_select_screen; waitkeyrelease;
        end;
  chr(k_f2):
        begin
        snddrvnum:=(snddrvnum+1) mod (sounddrvs_max+1);
        snd:=sounddrvs[snddrvnum];
        show_select_screen; waitkeyrelease;
        end;
  end;
 keydown:=true;
 end
   else begin
   inc(keycounter);
   if keycounter>20 then keydown:=false;
  end;
 end else keydown:=false;
{ Ende der Tastatureingabe }

{ Laufschrift: }
vidline:=0; vidpel:=0;
if (strcount1 =8) then begin
 inc(strcount2); if strcount2>length(banner) then strcount2:=1;
 textstyle.color:=70+(strcount2 mod 30);  textstyle.colorinc:=0;
 outtextxy(316,3,banner[strcount2]);
 strcount1:=0;
 end;

getsubimage(0,1,324,15,imbuf1);
putsubimage(0,0,0,324,15,imbuf1);
vidline:=tmp1; vidpel:=tmp2;
inc(strcount1);
until c=#27;
disalloc(imbuf1);
palfadeout;
end;



procedure titlepage;
var p:pbuffer;
    pblank:array[0..770] of byte;
    i,j:integer; xdim,ydim:word;
begin
p:=load_bitmap(150);
for i:=0 to 770 do pblank[i]:=0;
if p<>nil then begin
 xdim:=p^[0]+256*p^[1];
 ydim:=p^[2]+256*p^[3];
 setpalette(@pblank);
 for i:=0 to 20 do for j:=0 to 12 do
 clip16pattern(i shl 4,j shl 4,0,16,16,bitm[id_wall1]);
 clipbitmap(160-xdim shr 1,100-ydim shr 1,0,320,200,p);
 palfadein(mainpalette);
 for i:=1 to 500 do begin
  if getinput<>#0 then break;
  delay(10);
  end;
 palfadeout;
 disalloc(p);
 end;
end;


begin
init;
initvga;
centerscreen;
titlepage;
chooselevel;
textmode;
closeressource;
exitptr;
writeln('Thanx for playing BASH!');
writeln('BASH is freeware. If you liked it, you are encouraged to spread it all');
writeln('over the known world. You may give it to ya parents, ya grandparents,');
writeln('kiddies, ya cat, dog, to the fly on the wall or whomever you want to give it.');
end.
