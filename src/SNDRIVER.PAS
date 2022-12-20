unit sndriver;


interface
uses global,crt,dos,resunit;


type { SOUNDBLASTER }
     twpuffer=array[0..32000] of word;
     pwpuffer=^twpuffer;

type
   { INTERNER LAUTSPRECHER }
   psndintern=^sndintern;
   sndintern=object(snddrv)
    thesound:integer;
    function drvname:string; virtual;
    procedure initpoll; virtual;
    procedure setsfx(k:integer); virtual;
    procedure poll(i:integer); virtual;
   end;

   { SOUNDBLASTER DIGITAL }
   psndblast=^sndblast;
   sndblast=object(snddrv)
    mix:pwpuffer;
    playbuf:pbuffer;
    SbIOaddr:word;
    SbIRQ:word;
    SbDMAchan:word;
    sn1,sn2:integer;
    samples:array[0..5] of pbuffer;
    constructor init;
    destructor done;
    function drvname:string; virtual;
    function initdevice:boolean; virtual;
    procedure initpoll; virtual;
    procedure setsfx(k:integer); virtual;
    procedure poll(i:integer); virtual;
    procedure writedac(x:byte); virtual;
    procedure SetSampleRate; virtual;
    procedure SetVoice(state:integer); virtual;
    procedure addvoice(sn_id:integer); virtual;
    procedure OutVoice; virtual;
   end;



const { SOUNDBLASTER }
      DSP_WRITE_DATA=$C;
      DSP_WRITE_STATUS=$C;
      DMA=0;
      DMA_MASK=dma+10;
      DMA_FF=dma+12;
      DMA_MODE=dma+11;
      dmapage=$80;
      p=$228;

function add_device(p:psnd):boolean;


var   { SOUNDBLASTER }
      DMA_complete:integer;




implementation


{
*****************************************************************************
  INTERNER LAUTSPRECHER
*****************************************************************************
}
procedure sndintern.initpoll;
begin
thesound:=-1;
end;

procedure sndintern.setsfx(k:integer);
begin
if thesound<k then thesound:=k;
end;

procedure sndintern.poll(i:integer);
begin
case thesound of
 sn_walk:
  if (i>8) and (i<12) then sound(120-i shl 3) else nosound;
 sn_hit:
  if (i>1) and (i<5) then sound(50-random(50)) else nosound;
 sn_takediam:
  if i<15 then sound(800+i shl 6) else nosound;
 sn_alldiam:
  if (i shr 1) and 1<>0 then sound(800) else nosound;
 sn_explode:
   if i<16 then sound(20+random(60)) else nosound;
 end;
end;

function sndintern.drvname:string;
begin drvname:='PC Speaker'; end;



{
*****************************************************************************
  SOUNDBLASTER DIGITAL
*****************************************************************************
}

procedure sndblast.writedac(x:byte);
begin
while port[SbIOaddr+DSP_WRITE_STATUS] and $80<>0 do;
port[SBIOaddr+DSP_WRITE_DATA]:=x;
end;

procedure sndblast.SetSampleRate;
var tc:byte;
begin
{tc = 256 - (1000000/rate)}
tc:=131; { 131 entspricht rate=8000 Hz }
writedac($40);  {Command byte for sample rate}
writedac(tc);   {Sample rate time constant}
end;


procedure sndblast.SetVoice(state:integer);
{state=0 fr aus, sonst an}
begin
if state=0 then writedac($d3) else writedac($d1);
end;


procedure sndblast.OutVoice;
var t:integer; addr:longint; im,tm:byte;
begin dma_complete:=0;
im:=port[$21];
tm:=$ff xor (1 shl SbIRQ);
port[$21]:=im and tm;
port[dma_mask]:=5;
port[dma_ff]:=0;
port[dma_mode]:=$49;
addr:= longint(seg(playbuf^)) shl 4 + longint(ofs(playbuf^));
t:= byte(addr shr 16);
port[dmapage+3]:=t;
t := word(addr and $ffff);
port[dma+2*SbDMAchan]:=t and $ff;
port[dma+2*SbDMAchan]:=t shr 8;
port[dma+2*SbDMAchan+1]:=1800 and $ff;
port[dma+2*SbDMAchan+1]:=1800 shr 8;
port[dma_mask]:=sbdmachan;
writedac($48);
writedac(1800 and $ff);
writedac(1800 shr 8);
writedac($14);
writedac(1800 and $ff);
writedac(1800 shr 8);
end;


constructor sndblast.init;
begin
mix:=alloc(2*1800);
playbuf:=alloc(1800);
if (mix=nil) or (playbuf=nil) then error(err_outofmem);
{GetIntVec($08+SBIRQ,OldInt);
SetIntVec($08+SbIRQ,@SBHandler);}
end;

function sndblast.drvname:string;
begin drvname:='Soundblaster'; end;

function sndblast.initdevice:boolean;
begin
SbIOaddr:=$220;
SbIRQ:=7;
SbDMAchan:=1;
asm
    mov al,1
    mov dx,SbIOaddr
    add dx,6
    out dx,al
    in	al,dx
    in	al,dx
    in	al,dx
    in	al,dx
    mov al,0
    out dx,al
    add dx,4
    mov cx,100
@@1:
    in al,dx
    cmp al,0AAh
    je @@2
    loop @@1
    mov  ax,1
    jmp @ende
@@2:
    mov ax,0
    mov @result,al
@ende:
end;
writeln('Soundblaster detected');
samples[0]:=load_sample(1);
{ Hier noch die Samples laden!! }
SetSampleRate;
SetVoice(0);
end;

procedure sndblast.initpoll;
begin
fillchar(mix^,3600,0);
sn1:=-1; sn2:=-1;
end;


procedure sndblast.setsfx(k:integer);
begin
if (k>sn1) then begin
 if k<sn2 then sn1:=k else
 begin sn1:=sn2; sn2:=k end;
 end
end;

procedure sndblast.addvoice(sn_id:integer);
var id:integer; k:integer; p:pbuffer; sz:word;
begin
id:=-1;
case sn_id of
{  sn_walk       : id:=0;}
{  sn_hit        :}
  sn_takediam   : id:=1;
{  sn_alldiam    :}
{  sn_explode    :}
{  sn_quit       :}
  end;
if id>=0 then begin
 p:=samples[id];
 sz:=word(p^[0])+word(p^[1]) shl 8+2;
 for k:=2 to sz do inc(mix^[k],p^[k]);
end;
end;

procedure sndblast.poll(i:integer);
var p1,p2:longint;
begin
if i=1 then begin
  p1:=longint(playbuf); p2:=longint(mix);
  addvoice(sn1); addvoice(sn2);
  asm
  push ds
  les  di, p1
  lds  si, p2
  mov  cx,1800
  @lp:
  mov  ax,word ptr [ds:si]
  shr  ax,1
  mov  [es:di], al
  inc  di
  inc  si
  inc  si
  loop @lp
  pop  ds
  end;
  setvoice(0);
  OutVoice;
  setvoice(1);
 end;
end;

destructor sndblast.done;
begin
disalloc(mix); disalloc(playbuf);
end;



{***************************************************************************}


function add_device(p:psnd):boolean;
begin
if p^.initdevice then begin
 inc(sounddrvs_max);
 sounddrvs[sounddrvs_max]:=p;
 add_device:=true;
 end else begin add_device:=false; dispose(p); end;
end;

end.