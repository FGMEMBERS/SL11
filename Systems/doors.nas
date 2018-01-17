# doors ============================================================
var BDoor = aircraft.door.new( "/sim/model/door-positions/BDoor", 5, 0 );

var openBombDoors = func()
{
   BDoor.toggle();
}
