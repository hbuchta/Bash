{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0à
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: GLOBAL.PAS
Funktion : Unit mit globalen Definitionen

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


unit global;
{$G+}

interface
uses crt;

type  tbuffer=array[0..$fffe] of byte;
      pbuffer=^tbuffer;

      tpalette=array[0..767] of byte;        { Zur Aufname einer Palette }
      ppalette=^tpalette;

      plevel=^tlevel;           { Zur Aufname eines Levels }
      tlevel=record             { Als lineare Liste von    }
       name:string[20];         { Einzelspielen }
       diam:integer;
       enable:byte;             { 0=nein, 1=frei, 2=gel”st }
       packsize:word;           { gepackte Gr”áe der Spielfelddaten }
       x,y:integer;
       timer:word;
       data:pbuffer;
       next:plevel;
     end;


     snddrv=object
      constructor init;
      function drvname:string; virtual;
      function initdevice:boolean; virtual;
      procedure initpoll; virtual;
      procedure setsfx(k:integer); virtual;
      procedure poll(i:integer); virtual;
      end;
     psnd=^snddrv;



var   color              { aktuelle Zeichenfarbe }
        :byte;

      mydir              { Verzeichnis mit bash.exe }
        :string;
      exitptr:procedure; { Beendigungsroutine }
      thisvideomode:byte;{ aktueller Videomodus }
      origmode:byte;     { alter Videomodus }

      snd:psnd;          { Sounddevice }

      sounddrvs:array[0..5] of psnd;  { Soundeinheiten }
      sounddrvs_max:integer;          { Maximale Soundeinheit }

const
      sn_walk=0;
      sn_hit=5;
      sn_takediam=10;
      sn_alldiam=20;
      sn_explode=30;
      sn_quit=40;


const ciffer_string:array[0..7] of byte=
 (199,5,19,244,33,19,1,42);




procedure error(s:string);
function alloc(size:longint):pointer;
procedure disalloc(p:pointer);
procedure incr1(var p);
procedure incr(var p:pointer; i:longint);


const
 err_outofmem:string='out of memory';
 err_file:string='disk io';
 err_resfile:string='Illegal or corrupted ressource file';
 err_resnotfound:string='ressource not found in ressource file';

implementation



procedure standardexitproc; far;
begin
end;


procedure error(s:string);
begin
exitptr;
if thisvideomode>7 then
 asm
 mov   ah,0
 mov   al,origmode
 int   10h
 end;
writeln;
writeln;
writeln('Critical error:',s);
writeln;
writeln('Program termination');
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
@ok:mov  segment,ax
end;
alloc:=ptr(segment,0);
{getmem(p,size);
alloc:=p;}
end;


procedure disalloc(p:pointer);
begin
asm
   les   dx,p
   mov   ah,49h
   int   21h
end;
{dispose(p);}
end;



procedure incr1(var p); assembler;
asm
    les   bx,p
    mov   ax,es:[bx]
    inc   ax
    mov   es:[bx],ax
    jnz   @ok
    mov   ax,es:[bx+2]
    mov   ax,$1000
    add   es:[bx+2],ax
@ok:
end;


procedure incr(var p:pointer; i:longint);
var t:longint;
begin
t:=(longint(seg(p^)) shl 4)+ofs(p^)+i;
p:=ptr(t div 16,t mod 16);
end;


{ "NoSound" Soundtreiber }
constructor snddrv.init;
begin end;
function snddrv.drvname:string;
begin drvname:='No sound'; end;
function snddrv.initdevice;
begin initdevice:=true; end;
procedure snddrv.initpoll;
begin end;
procedure snddrv.setsfx(k:integer);
begin end;
procedure snddrv.poll(i:integer);
begin end;


begin
exitptr:=standardexitproc;
new(snd,init); sounddrvs_max:=0;
sounddrvs[0]:=snd;
end.
