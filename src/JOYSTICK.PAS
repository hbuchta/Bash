{
--------------------------------------------------
File:     JOYSTICK.PAS
By:       Ronny Wester, ronny@rat.se

Code to read PC sticks.
Written with kind assistance of Christian Wagner.
--------------------------------------------------
}
unit Joystick;


interface


type
  JoyRec =
    record
      centerx,centery:word;
      present : Boolean;
      x, y : Word;
      button1,
      button2,
      button3,
      button4 : Boolean;
    end;

var

  gStick : JoyRec;


procedure PollJoystick;
function TestJoystick:boolean;
procedure CenterJoystick;


implementation


const

  cStickPort = $0201;


procedure Polljoystick;
var b : Byte;
    mask : Byte;
    laps : Word;
begin
  mask := 0;
  if gStick.present then
    mask := 3;
  FillChar( gStick.present, SizeOf( gStick)-4, 0);
  laps := 0;

  asm cli end;

  Port[ cStickPort] := $FF; { Write anything to trigger countdown }
  repeat
    b := Port[ cStickPort];
    if b and 1 <> 0 then
      Inc( gStick.x);
    if b and 2 <> 0 then
      Inc( gStick.y);
    Inc( laps);
  until (b and mask = 0) or (laps > 60000); { Timeout if no sticks connected }

  asm sti end;

  gStick.present := b and 3 = 0;

  if gStick.present then
  begin
    gStick.button1 := b and 16 = 0;
    gStick.button2 := b and 32 = 0;
    gStick.button3 := b and 64 = 0;
    gStick.button4 := b and 128 = 0;
  end;
end;



function TestJoystick:boolean;
begin
gStick.present:=true;
PollJoystick;
TestJoystick:=gstick.present;
end;



procedure Centerjoystick;
begin
PollJoystick;
with gstick do begin centerx:=x; centery:=y; end;
end;


end.
