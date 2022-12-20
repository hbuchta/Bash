{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASH   Version 1.0à
(c) 1994 Hilmar Buchta

Dokumentation siehe: technote.doc

Dateiname: VGA256.PAS
Funktion : Unit mit den Grafikfunktionen

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}


unit vga256;
{$G+}

interface
uses global,crt;

{*************************************************************************
                      Variablen
**************************************************************************}

type ttextdata=record
     color:byte;
     colorinc:byte;
     memptr:pointer;
     celhigh:byte;
     end;


var
    vidline:word;          { Basisadresse des aktuellen Bildes div 4 }
    vidPEL:byte;           { Basisadresse des aktuellen Bildes mod 4 }
    vidadr:longint;

const textstyle:ttextdata
 =(color:70;colorinc:1;memptr:ptr($f000,$fa6e);celhigh:8);




{*************************************************************************
                      Init Funktionen
**************************************************************************}
procedure initvga;
{ Schaltet auf VGA Modus 13h (320x200/256) um }
procedure TextMode;
{ Schaltet auf Standard Textmodus 3h zurck }


{*************************************************************************
                      Standard Grafikroutinen
**************************************************************************}
procedure Pset(x,y:integer);
{ Setzt Punkt x,y in der Farbe color }
procedure putsubimage(line,pel,pos1,cdx,cdy:word; p:pointer);
{ Setzt den bei pos1 beginnenden Bildausschnitt der Gr”áe cdx*cdy
von p an die Stelle pos}
procedure getsubimage(line,pel,cdx,cdy:word; p:pointer);
function  ImageSize(a,b,c,d:word):word;
{ Liefert Speichergr”áe des Bildes }
procedure OutTextXY(x,y:integer;s:string);
{ Stellt Text dar }
procedure bar(x,y,cdx,cdy:word; col:byte);
{ Fllt das Rechteck a,b,c,d in der Farbe col aus }

procedure hline(x,y,cdx:word; col:byte);
procedure vline(x,y,cdy:word; col:byte);



{*************************************************************************
                      Paletten-Befehle
**************************************************************************}
procedure setpalette(pal:pbuffer);
{ Setzt die Palette pal als aktuelle Palette }
procedure palfadeout;
{ Blendet das aktuelle Bild aus }
procedure palfadein(pal:pbuffer);
{ Blendet das aktuelle Bild in der neuen Palette pal ein }
procedure getpalette(p:pbuffer);
{ Liest die aktuelle Palette nach p. Der Speicher fr p muá bereits
  reserviert sein (768 Byte) }


{*************************************************************************
                      Scroll-Befehle
**************************************************************************}

procedure centerscreen;
{ Stellt das Bild auf die Basisposition zuck }
procedure verticalretrace;
{ Wartet auf vertikalen Zeilenrcklauf }
procedure scroll(ofs:integer);
{ Scrollt den Bildschirm:
   1  : nach links
  -1  : nach rechts
 328  : nach oben
-328  : nach unten
centerscreen wird automatisch aufgerufen, so daá sich der Anwender auáer
um das Auffllen der neu sichtbar gewordenen Bereiche um nichts kmmern
muá...
}

procedure setreg(x:word;pel:byte);




implementation


procedure initvga;
var lese:byte;
begin
asm
   mov ah,0
   mov al,13h
   int 10h
end;
origmode:=thisvideomode; thisvideomode:=$13;
port[$3c4]:=4; lese:=(port[$3c5] and (255-8)) or 4;
port[$3c5]:=lese;
port[$3ce]:=5; lese:=(port[$3cf] and (255-$10));
port[$3cf]:=lese;
port[$3ce]:=6;
lese:=(port[$3cf] and (255-2));
port[$3cf]:=lese;
port[$3c4]:=2;
port[$3c5]:=$0f;
port[$3d4]:=$14;
lese:=(port[$3d5] and (255-$40));
port[$3d5]:=lese;
port[$3d4]:=$17;
lese:=(port[$3d5] or $40);
port[$3d5]:=lese;
fillchar(ptr($a000,0000)^,64000,0);
asm
 mov dx, 3D4h       { set screen width to 328 pixels for better panning }
 mov al, 13h        { (physical width is still 320) }
 out dx, al
 inc dx
 mov al, 41         {  41*8=328 }
 out dx, al
end;
end;


procedure TextMode;
begin
if thisvideomode>10 then
asm
      mov       ah,0
      mov       al,origmode;
      int       $10;
end;
thisvideomode:=origmode;
end;



{************************************************************************}

procedure Pset(x,y:integer);
var offset:word; plane:byte;
begin
offset:=y*82+(x div 4)+vidline;
plane:=1 shl (x mod 4+vidpel);
port[$3c4]:=2;
port[$3c5]:=plane;
mem[$a000:offset]:=color;
end;



procedure putsubimage(line,pel,pos1,cdx,cdy:word; p:pointer); assembler;
var  deltax,pixnum:word;
asm
       mov   al,vidpel
       xor   ah,ah
       add   ax,pel
       mov   cx,ax                { Berechne Portausgabewert der Seite, }
       and   cl,3                 { die die erste Spalte enth„lt in bl  }
       mov   bl,1
       shl   bl,cl
       shr   ax,2
       add   ax,line
       add   ax,vidline           { linken Ecke nach di }
       mov   di,ax
       mov   ax,0a000h            { Setze es=Ausgabesegment }
       mov   es,ax
       push  ds
       lds   si,p                 { Setze ds:si=Quelladresse }
       mov   ax,word ptr [ds:si]  { Speichere x-Ausdehnung des Bildes als }
       mov   deltax,ax            { als deltax ab. }
       add   si,4                 { erster Pixel, }
       add   si,pos1              {  der ausgegeben werden muá }
       mov   cx,4                 { Alle 4 Planes durchgehen }
       mov   dx,03c4h             { fr Seitenauswahl }
       cld
@lp1:  push  di
       push  si
       push  cx
       mov   ax,cdx               { Berechne Anzahl der Ausgabepixel }
       dec   ax                   { pro Zeile nach ax }
       add   ax,cx
       shr   ax,2
       or    ax,ax                { Keine Pixel auf dieser Seite ? }
       jz    @nextpage            { dann n„chste Seite probieren }
       mov   pixnum,ax            { Anzahl Pixel abspeichern }
       mov   al,2                 { diese Seite w„hlen }
       out   dx,al
       mov   al,bl
       inc   dx
       out   dx,al
       dec   dx
       mov   cx,cdy               { Anzahl Zeilen }
@lp2:  push  cx
       push  si
       push  di
       mov   cx,pixnum
@lp3:  movsb                      { Byte kopieren }
       inc   si
       inc   si
       inc   si                   { n„chstes Byte im Quelltext adressieren }
       loop  @lp3
       pop   di
       pop   si
       pop   cx
       add   si,deltax            { N„chste Zeile adressieren }
       add   di,82
       loop  @lp2                 { restliche Zeilen ausgeben }
@nextpage:
       pop   cx
       pop   si
       pop   di
       inc   si                   { Offset fr n„chste Plane ist 1 gr”áer }
       shl   bl,1                 { Wert fr n„chste Seite nach bl }
       cmp   bl,8
       jna   @cnt1
       mov   bl,1
       inc   di
@cnt1:
       loop  @lp1
       pop   ds
end;


procedure getsubimage(line,pel,cdx,cdy:word; p:pointer); assembler;
var  deltax,pixnum:word;
asm
       mov   al,vidpel
       xor   ah,ah
       add   ax,pel
       mov   cx,ax                { Berechne Portausgabewert der Seite, }
       and   cl,3                 { die die erste Spalte enth„lt in bl  }
       mov   bl,cl
       shr   ax,2
       add   ax,line
       add   ax,vidline           { linken Ecke nach di }
       mov   si,ax
       mov   ax,0a000h            { Setze es=Ausgabesegment }
       push  ds
       mov   ds,ax
       les   di,p                 { Setze ds:si=Quelladresse }
       mov   ax,cdx
       mov   word ptr [es:di],ax
       mov   deltax,ax            { als deltax ab. }
       mov   ax,cdy
       mov   word ptr [es:di+2],ax
       add   di,4                 { erster Pixel, }
       mov   cx,4                 { Alle 4 Planes durchgehen }
       mov   dx,03ceh             { fr Seitenauswahl }
       cld
@lp1:  push  di
       push  si
       push  cx
       mov   ax,cdx               { Berechne Anzahl der Ausgabepixel }
       dec   ax                   { pro Zeile nach ax }
       add   ax,cx
       shr   ax,2
       or    ax,ax                { Keine Pixel auf dieser Seite ? }
       jz    @nextpage            { dann n„chste Seite probieren }
       mov   pixnum,ax            { Anzahl Pixel abspeichern }
       mov   al,4                 { diese Seite zum Lesen ausw„hlen }
       out   dx,al
       mov   al,bl
       inc   dx
       out   dx,al
       dec   dx
       mov   cx,cdy               { Anzahl Zeilen }
@lp2:  push  cx
       push  si
       mov   cx,pixnum
@lp3:
       movsb                      { Byte kopieren }
       inc   di
       inc   di
       inc   di                   { n„chstes Byte im Quelltext adressieren }
       loop  @lp3
       pop   si
       pop   cx
       add   si,82
       loop  @lp2                 { restliche Zeilen ausgeben }
@nextpage:
       pop   cx
       pop   si
       pop   di
       inc   di                   { Offset fr n„chste Plane ist 1 gr”áer }
       inc   bl                   { Wert fr n„chste Seite nach bl }
       cmp   bl,4
       jb    @cnt1
       mov   bl,0
       inc   si
@cnt1:
       loop  @lp1
       pop   ds
end;






function ImageSize(a,b,c,d:word):word;
begin
ImageSize:=abs((c-a+1)*(d-b+1))+4;
end;



procedure outtextxy(x,y:integer; s:string); assembler;
var chnum,safe_ds:word; plane,bitmask1,bitmask2:byte; col,colinc:byte;
asm
    mov   al,textstyle.color
    mov   col,al
    mov   al,textstyle.colorinc
    mov   colinc,al
    mov   cx,x
    add   cl,vidpel
    and   cl,3
    mov   bl,1
    shl   bl,cl           { Seitenauswahlwert nach bl }
    mov   plane,bl
    mov   ax,y
    mov   bl,82
    mul   bl
    mov   bx,x            { Adresse im Bildschirmspeicher ermitteln }
    shr   bx,2
    add   ax,bx
    add   ax,vidline
    mov   di,ax
    mov   ax,0a000h
    mov   es,ax           { Ziel ist es:di, Plane steht in Variable plane }
    mov   bitmask1,128
    mov   bitmask2,8
    mov   ax,ds
    mov   safe_ds,ax
    lds   si,s
    mov   cl,[ds:si]
    or    cl,cl
    jz    @notext
    inc   si
    xor   ch,ch           { cx = Anzahl auszugebender Zeichen }
    mov   chnum,cx
    mov   cx,4            { 4 Planes sind zu bearbeiten }
@ploop:
    push  di
    push  si
    mov   dx,03c4h
    mov   al,2            { aktuelle Seite w„hlen }
    out   dx,al
    mov   al,plane
    inc   dx
    out   dx,al
    push  cx
    mov   cx,chnum
@cloop:
    push  ds
    mov   ax,safe_ds
    mov   ds,ax
    les   bx,textstyle.memptr
    pop   ds
    lodsb                { Zeichen laden }
    xor   ah,ah
    shl   ax,3
    add   bx,ax          { Anfang des Zeichens jetzt in es:bx }
    push  di
    push  cx
    mov   cx,8           { 8 Zeilen }
    mov   dl,col          {mov  dl,[cs:text.color]}
@cloop1:
    mov   al,[es:bx]
    and   al,bitmask1
    jz    @clp1
    push  es
    mov   ax,0a000h
    mov   es,ax
    mov   [es:di],dl
    pop   es
@clp1:
    mov   al,[es:bx]
    and   al,bitmask2
    jz    @clp2
    push  es
    mov   ax,0a000h
    mov   es,ax
    mov   [es:di+1],dl
    pop   es
@clp2:
    inc   bx
    add   di,82
    add   dl,colinc              { add dl,[cs:text.colorinc] }
    loop  @cloop1
    pop   cx
    pop   di
    inc   di
    inc   di
    loop  @cloop
    pop   cx
    shr   [ss:bitmask1],1
    shr   [ss:bitmask2],1
    pop   si
    pop   di
    mov   bl,[ss:plane]
    shl   bl,1
    cmp   bl,8
    jna   @l0
    mov   bl,1
    inc   di
@l0:
    mov   [ss:plane],bl
    loop  @ploop
@notext:
    mov   ax,safe_ds
    mov   ds,ax
end;




procedure bar(x,y,cdx,cdy:word; col:byte); assembler;
var  pixnum:word;
asm
       mov   ax,y
       mov   bl,82
       mul   bl
       mov   bx,x            { Adresse im Bildschirmspeicher ermitteln }
       shr   bx,2
       add   ax,bx
       add   ax,vidline
       mov   di,ax
       mov   cx,x
       add   cl,vidpel
       and   cl,3
       mov   bl,1
       shl   bl,cl           { Seitenauswahlwert nach bl }
       mov   ax,0a000h            { Setze es=Ausgabesegment }
       mov   es,ax
       mov   cx,4                 { Alle 4 Planes durchgehen }
       mov   dx,03c4h             { fr Seitenauswahl }
       cld
@lp1:  push  di
       push  cx
       mov   ax,cdx               { Berechne Anzahl der Ausgabepixel }
       dec   ax                   { pro Zeile nach ax }
       add   ax,cx
       shr   ax,2
       or    ax,ax                { Keine Pixel auf dieser Seite ? }
       jz    @nextpage            { dann n„chste Seite probieren }
       mov   pixnum,ax            { Anzahl Pixel abspeichern }
       mov   al,2                 { diese Seite w„hlen }
       out   dx,al
       mov   al,bl
       inc   dx
       out   dx,al
       dec   dx
       mov   cx,cdy               { Anzahl Zeilen }
@lp2:  push  cx
       push  di
       mov   cx,pixnum
       mov   al,col
       rep stosb                  { Bytes schreiben }
       pop   di
       pop   cx
       add   di,82
       loop  @lp2                 { restliche Zeilen ausgeben }
@nextpage:
       pop   cx
       pop   di
       shl   bl,1                 { Wert fr n„chste Seite nach bl }
       cmp   bl,8
       jna   @cnt1
       mov   bl,1
       inc   di
@cnt1:
       loop  @lp1
end;



procedure hline(x,y,cdx:word; col:byte);
begin bar(x,y,cdx,1,col); end;

procedure vline(x,y,cdy:word; col:byte);
begin bar(x,y,1,cdy,col); end;

{************************************************************************}


procedure setpalette(pal:pbuffer); assembler;
asm
        push    ds
        lds     bx,pal
        mov     dx,03c8h
        mov     cx,256
        xor     di,di
@lp:    mov     ax,di
        out     dx,al
        inc     dx
        mov     al,[ds:bx]
        out     dx,al
        inc     bx
        mov     al,[ds:bx]
        out     dx,al
        inc     bx
        mov     al,[ds:bx]
        out     dx,al
        inc     bx
        dec     dx
        inc     di
        loop    @lp
        pop     ds
end;


procedure getpalette(p:pbuffer); assembler;
asm
        les    dx,p
        xor    bx,bx
        mov    cx,100h
        mov    ax,1017h
        int    10h
end;



procedure palfadeout;
var p:array[0..767] of byte;
    k,i:integer;
begin
getpalette(@p);
for k:=1 to 64 do begin
 for i:=0 to 767 do begin
  if p[i]>0 then dec(p[i]);
  end;
 verticalretrace; setpalette(@p);
 delay(17);
 end;
end;

procedure palfadein(pal:pbuffer);
var p:array[0..767] of byte;
    k,i:integer; b:byte;
begin
for k:=63 downto 0 do begin
 for i:=0 to 767 do begin
  b:=pal^[i]; if b>k then dec(b,k) else b:=0;
  p[i]:=b;
  end;
 verticalretrace; setpalette(@p);
 delay(17);
 end;
end;




{************************************************************************}


procedure verticalretrace; assembler;
asm
    mov dx,3DAh
@l1:
    in al,dx
    and al,08h
    jz @l1
@l2:
    in al,dx
    and al,08h
    jnz  @l2
end;



procedure setvgaregisters; assembler;
{ setzt line auf cx und PEL auf bl
  ge„ndert wird der Wert von al und dx }

asm
   mov   dx,03dah
   in    al,dx
   mov   dx,03c0h
   mov   al,13h
   out   dx,al
   mov   al,bl
   out   dx,al
   mov   al,20h
   out   dx,al
   mov   dx,03d4h
   mov   al,0dh
   out   dx,al
   mov   al,cl
   inc   dx
   out   dx,al
   dec   dx
   mov   al,0ch
   out   dx,al
   mov   al,ch
   inc   dx
   out   dx,al
end;



procedure setreg(x:word;pel:byte); assembler;
asm
   mov   cx,x
   mov   bl,pel
   call  setvgaregisters
end;




procedure centerscreen;
begin
asm
   push ds
   mov  si,vidline
   mov  di,32000
   mov  ax,0a000h
   mov  ds,ax
   mov  es,ax
   mov  cx,16400
   cld
   mov  dx,03ceh
   mov  ax,0008h
   out  dx,ax
   mov  dx,03c5h
   mov  al,0fh
   out  dx,al
   rep  movsb
   mov  dx,03cfh
   mov  al,0ffh
   out  dx,al
   pop  ds
end;
vidline:=32000;
setreg(vidline, vidpel shl 1);
end;


procedure scroll(ofs:integer);
var vidadr:longint;
begin
vidadr:=longint(vidline) shl 2+longint(vidpel)+longint(ofs);
vidline:=vidadr shr 2;
vidpel:=vidadr and 3;
if (vidline<16000) or (vidline>48000) then centerscreen;
setreg(vidline,vidpel shl 1);
end;



begin
vidadr:=0; vidline:=0; vidpel:=0;
asm
  mov  ah,0fh
  int  10h
  mov  thisvideomode,al
end;
end.
