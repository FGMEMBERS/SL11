###############################################################################
##
## Zeppelin LZ 121 "Nordstern" airship for FlightGear.
##
##  Copyright (C) 2010 - 2016  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

###############################################################################
# External API
#
# autoWeightOff()
# printWOW()
# shiftTrimBallast(direction, amount)
# releaseBallast(location, amount)
# refillQuickReleaseBallast(location)
# setForwardGasValves()
# setAftGasValves()
# switchEngineDirection(engine)
# about()
#

# Constants
var FORWARD = -1;
var AFT     = -2;
var FORE_BALLAST = -1;
var AFT_BALLAST = -2;
var QUICK_RELEASE_BAG_CAPACITY = 220.5; # lb
var TRIM_BAG_CAPACITY = 4500.0; # lb

var mixture_timer = 0;
var sight_timer = 0;

###############################################################################
var weight_on_gear_p = "/fdm/jsbsim/forces/fbz-gear-lbs";

var trim_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[4]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[5]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[6]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[7]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[8]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[9]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[10]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[11]"
    ];
var fore_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[12]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[13]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[14]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[15]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[16]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[17]"
    ];
var fore_ballast_toggles_p =
    [
     "/controls/ballast/release[0]",
     "/controls/ballast/release[1]",
     "/controls/ballast/release[2]",
     "/controls/ballast/release[3]",
     "/controls/ballast/release[4]",
     "/controls/ballast/release[5]",
    ];
var aft_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[0]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[2]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[3]"
    ];
var aft_ballast_toggles_p =
    [
     "/controls/ballast/release[6]",
     "/controls/ballast/release[7]",
     "/controls/ballast/release[8]",
     "/controls/ballast/release[9]"
    ];

var printWOW = func
{
	if (getprop("/gear/gear[0]/wow"))
	{
		gui.popupTip("Current weight on gear " ~ -getprop(weight_on_gear_p) ~ " lbs.");
	}
	else
	{
		gui.popupTip("Current lift " ~ getprop("/fdm/jsbsim/static-condition/net-lift-lbs") ~ " lbs.");
	}
}

# Weight off to neutral
var autoWeighoff = func
{
	var lift = getprop("/fdm/jsbsim/static-condition/net-lift-lbs");
	var n = size(trim_ballast_p);
	print("SL.11: Auto weigh off from " ~ (-lift) ~ " lb heavy to neutral.");
	foreach(var p; trim_ballast_p)
	{
		var v = getprop(p) + lift/n;
		interpolate(p, (v > 0 ? v : 0), 0.5);
	}
}

var initial_weighoff = func {
    # Set initial static condition.
    # Finding the right static condition at initialization time is tricky.
    autoWeighoff();
    settimer(autoWeighoff, 0.25);
    settimer(autoWeighoff, 1.0);
}

var init_all = func(reinit=0) {
#    initial_weighoff();

#    fake_electrical();
    # Disable the autopilot menu.
    #gui.menuEnable("autopilot", 0);

    if (!reinit) {
        # Livery support.
#        aircraft.livery.init("Aircraft/ZLT-NT/Models/Liveries")

        # Create FG /controls/gas/ aliases for FDM owned controls.
        var fdm = "fdm/jsbsim/buoyant_forces/gas-cell";
        props.globals.getNode(gascell ~ "[0]", 1).
            alias(props.globals.getNode(fdm ~ "[11]/valve_open"));
        props.globals.getNode(gascell ~ "[1]", 1).
            alias(props.globals.getNode(fdm ~ "[10]/valve_open"));
        props.globals.getNode(gascell ~ "[2]", 1).
            alias(props.globals.getNode(fdm ~ "[1]/valve_open"));
        props.globals.getNode(gascell ~ "[3]", 1).
            alias(props.globals.getNode(fdm ~ "[0]/valve_open"));
            settimer(func {
                ground_crew.place_ground_crew
                    (geo.aircraft_position(),
                     getprop("/orientation/heading-deg"));
                ground_crew.activate();
            }, 0.5);
    }
    mixture_timer = maketimer(1, updateMixture);
    mixture_timer.start();
    sight_timer = maketimer(1, updateBombSight);
    setlistener("/sim/current-view/name", checkView);
    print("SL11 Systems ... Check");
}

var _nordstern_initialized = 0;
setlistener("/sim/signals/fdm-initialized", func {
    init_all(_nordstern_initialized);
    _nordstern_initialized = 1;
	setprop("/fdm/jsbsim/crew/helmsman/heading-magnetic-cmd-deg" , getprop("/orientation/heading-deg"));
	setprop("/fdm/jsbsim/crew/elevatorman/altitude-cmd-ft" , getprop("/position/altitude-ft"));
	setprop("/autopilot/settings/target-pitch-deg" , 0);
    setprop("/controls/engines/engine[0]/opstatereq", 0);
    setprop("/controls/engines/engine[0]/opstateresp", 0);
    setprop("/controls/engines/engine[1]/opstatereq", 0);
    setprop("/controls/engines/engine[1]/opstateresp", 0);
    setprop("/controls/engines/engine[2]/opstatereq", 0);
    setprop("/controls/engines/engine[2]/opstateresp", 0);
    setprop("/controls/engines/engine[3]/opstatereq", 0);
    setprop("/controls/engines/engine[3]/opstateresp", 0);
});

###############################################################################
# Ballast controls

var shiftTrimBallast = func(direction, amount) {
    var from = nil;
    var to = nil;
    if (direction == FORWARD) {
        from = [trim_ballast_p[0], trim_ballast_p[1]];
        to   = [trim_ballast_p[6], trim_ballast_p[7]];
    } elsif (direction == AFT) {
        from = [trim_ballast_p[6], trim_ballast_p[7]];
        to   = [trim_ballast_p[0], trim_ballast_p[1]];

    } else {
        printlog("warn",
                 "SL11.shiftTrimBallast(" ~ direction ~ ", " ~ amount ~
                 "): Invalid direction.");
        return;
    }
    foreach (var p; from) {
        SmoothTransfer.new(p, to[0],
                           2.0,
                           0.25*amount);
        SmoothTransfer.new(p, to[1],
                           2.0,
                           0.25*amount);
    }
}

# Release one or more quick-release ballast units.
var releaseBallast = func(location, amount) {
    var units   = nil;
    var toggles = nil;
    if (location == FORE_BALLAST) {
        units   = fore_ballast_p;
        toggles = fore_ballast_toggles_p;
    } elsif (location == AFT_BALLAST) {
        units   = aft_ballast_p;
        toggles = aft_ballast_toggles_p;
    } else {
        printlog("warn",
                 "SL11.releaseBallast(" ~ location ~ ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    forindex (var i; units) {
        if (!amount) return;
        if (getprop(units[i]) > 0.0) {
            #interpolate(units[i], 0.0, 1.0);
            setprop(toggles[i], 1.0);
            amount -= 1;
        }
    }
}

# Refills empty "ballasthosen" from the trim ballast bags.
var refillQuickReleaseBallast = func(location) {
    var units   = nil;
    var toggles = nil;
    if (location == FORE_BALLAST) {
        units   = fore_ballast_p;
        toggles = fore_ballast_toggles_p;
    } elsif (location == AFT_BALLAST) {
        units   = aft_ballast_p;
        toggles = aft_ballast_toggles_p;
    } else {
        printlog("warn",
                 "SL11.refillQuickReleaseBallast(" ~ location ~
                 ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    var n = size(trim_ballast_p);
    forindex (var qb; units) {
        var v = getprop(units[qb]);
        if (v < QUICK_RELEASE_BAG_CAPACITY) {
            setprop(toggles[qb], 0.0);
            foreach(var tb; trim_ballast_p) {
                SmoothTransfer.new(tb, units[qb],
                                   2.0,
                                   (QUICK_RELEASE_BAG_CAPACITY - v)/n);
            }
        }
    }
}

# Listen to the /controls/ballast/release[x] controls.
forindex(var i; fore_ballast_toggles_p) {
    setlistener(fore_ballast_toggles_p[i], func (n) {
        interpolate(fore_ballast_p[n.getIndex()], 0.0, 1.0);
    }, 0, 0);
}
forindex(var i; aft_ballast_toggles_p) {
    setlistener(aft_ballast_toggles_p[i], func (n) {
        interpolate(aft_ballast_p[n.getIndex() - size(fore_ballast_toggles_p)],
                    0.0, 1.0);
    }, 0, 0);
}


###############################################################################
# Gas valve controls
var gascell = "controls/gas/valve-cmd-norm";

var setForwardGasValves = func (v) {
    setprop(gascell ~ "[0]", v);
    setprop(gascell ~ "[1]", v);
}

var setAftGasValves = func (v) {
    setprop(gascell ~ "[2]", v);
    setprop(gascell ~ "[3]", v);
}


###############################################################################
# Engine controls.
var switchEngineDirection = func (eng) {
    var engineJSB = "/fdm/jsbsim/propulsion/engine" ~ "[" ~ eng ~ "]";
    var engineFG  = "/engines/engine" ~ "[" ~ eng ~ "]";
    var dir       = engineJSB ~ "/yaw-angle-rad";

    # Only engine 0 and 1 can be reversed.
    if ((eng < 0) or (eng > 1)) return;

    if (!getprop(engineFG ~ "/running")) {
        setprop(dir, (getprop(dir) == 0) ? 3.14159265 : 0.0);
        # NOTE: The popup tip should probably be at the callers discretion. 
        gui.popupTip("Engine " ~ eng ~
                     " set to " ~
                     ((getprop(dir) == 0) ? "forward." : "reverse."));
    } else {
        # NOTE: The popup tip should probably be at the callers discretion. 
        gui.popupTip("Cannot change direction for " ~
                     ((getprop(dir) == 0) ? "forward" : "reverse") ~
                     " running engine " ~ eng ~ ".");
    }
}

var GetTankState = func(eng)
{
   if (eng == 0)
   {
      if (getprop("/consumables/fuel/tank[3]/empty") and getprop("/consumables/fuel/tank[4]/empty") and getprop("/consumables/fuel/tank[5]/empty"))
      {
         return 0;
      }
      else
      {
         return 1;
      }
   }
   if (eng == 1)
   {
      if (getprop("/consumables/fuel/tank[6]/empty") and getprop("/consumables/fuel/tank[7]/empty") and getprop("/consumables/fuel/tank[8]/empty"))
      {
         return 0;
      }
      else
      {
         return 1;
      }
   }
   if (eng == 2)
   {
      if (getprop("/consumables/fuel/tank[9]/empty") and getprop("/consumables/fuel/tank[10]/empty") and getprop("/consumables/fuel/tank[11]/empty"))
      {
         return 0;
      }
      else
      {
         return 1;
      }
   }
   if (eng == 3)
   {
      if (getprop("/consumables/fuel/tank[0]/empty") and getprop("/consumables/fuel/tank[1]/empty") and getprop("/consumables/fuel/tank[2]/empty"))
      {
         return 0;
      }
      else
      {
         return 1;
      }
   }
}

var SetEngineState = func (eng, state)
{
    var engineJSB = "/fdm/jsbsim/propulsion/engine" ~ "[" ~ eng ~ "]";
    var engineFG  = "/engines/engine" ~ "[" ~ eng ~ "]";
    var engineCon = "/controls/engines/engine" ~ "[" ~ eng ~ "]";
    var dir       = engineJSB ~ "/yaw-angle-rad";
    if (GetTankState(eng) == 0)
    {
        setprop(engineCon ~ "/cutoff", 1);
        setprop(engineCon ~ "/throttle", 0.0);
        setprop(engineCon ~ "/magnetos", 0);
        setprop(engineCon ~ "/starter", 0);
        setprop(dir, 0);
        setprop(engineCon ~ "/opstatereq", 0);
        settimer(func { setprop(engineCon ~ "/opstateresp", 0); }, 3);
        return;
    }
    if (getprop(engineFG ~ "/running"))
    {
        if (state == -1)
        {
            if ((eng < 0) or (eng > 1))
               return;
            setprop(engineCon ~ "/starter", 0);
            setprop(engineCon ~ "/throttle", 0.6);
            setprop(engineCon ~ "/opstatereq", -1);
            setprop(dir, 3.14159265);
            settimer(func { setprop(engineCon ~ "/opstateresp", -1); }, 3);
        }
        if (state == -2)
        {
            if ((eng < 0) or (eng > 1))
               return;
            setprop(engineCon ~ "/starter", 0);
            setprop(engineCon ~ "/throttle", 0.85);
            setprop(engineCon ~ "/opstatereq", -2);
            setprop(dir, 3.14159265);
            settimer(func { setprop(engineCon ~ "/opstateresp", -2); }, 3);
        }
        if (state == 0)
        {
            setprop(engineCon ~ "/cutoff", 1);
            setprop(engineCon ~ "/throttle", 0.0);
            setprop(engineCon ~ "/magnetos", 0);
            setprop(engineCon ~ "/starter", 0);
            setprop(dir, 0);
            setprop(engineCon ~ "/opstatereq", 0);
            settimer(func { setprop(engineCon ~ "/opstateresp", 0); }, 3);
        }
        if (state == 1)
        {
            setprop(engineCon ~ "/starter", 0);
            setprop(engineCon ~ "/throttle", 0.01);
            setprop(dir, 0);
            setprop(engineCon ~ "/opstatereq", 1);
            settimer(func { setprop(engineCon ~ "/opstateresp", 1); }, 3);
        }
        if (state == 2)
        {
            setprop(engineCon ~ "/starter", 0);
            setprop(engineCon ~ "/throttle", 0.6);
            setprop(dir, 0);
            setprop(engineCon ~ "/opstatereq", 2);
            settimer(func { setprop(engineCon ~ "/opstateresp", 2); }, 3);
        }
        if (state == 3)
        {
            setprop(engineCon ~ "/starter", 0);
            setprop(engineCon ~ "/throttle", 0.85);
            setprop(dir, 0);
            setprop(engineCon ~ "/opstatereq", 3);
            settimer(func { setprop(engineCon ~ "/opstateresp", 3); }, 3);
        }
        if (state == 4)
        {
            setprop(engineCon ~ "/starter", 0);
            if (getprop("/position/altitude-ft") > 6000.0)
            {
               setprop(engineCon ~ "/throttle", 1.0);
               setprop(dir, 0);
               setprop(engineCon ~ "/opstatereq", 4);
               settimer(func { setprop(engineCon ~ "/opstateresp", 4); }, 3);
            }
            else
            {
               setprop(engineCon ~ "/throttle", 1.0);
               setprop(dir, 0);
               setprop(engineCon ~ "/opstatereq", 4);
               settimer(func { setprop(engineCon ~ "/opstateresp", 5); }, 3);
               settimer(func { if (getprop(engineCon ~ "/opstateresp") == 5) { SetEngineState(eng, 3); } }, 90);
            }
        }
    }
    else
    {
        if (state != 0)
        {
           setprop(engineCon ~ "/cutoff", 0);
           setprop(engineCon ~ "/throttle", 0.9);
           setprop(engineCon ~ "/magnetos", 3);
           setprop(engineCon ~ "/starter", 1);
           setprop(engineCon ~ "/opstatereq", 1);
           setprop(engineCon ~ "/opstateresp", 0);
           setprop(dir, 0);
           var engineRunning = setlistener(engineFG ~ "/running", func {
              if (getprop(engineFG ~ "/running"))
              {
                 setprop(engineCon ~ "/starter", 0);
                 setprop(engineCon ~ "/throttle", 0.01);
                 removelistener(engineRunning);
                 setprop(engineCon ~ "/opstateresp", 1);
              }
           });
       }
    }
}

var updateMixture = func()
{
   if (getprop("/position/altitude-ft") < 6000.0)
   {
      if (getprop("/controls/engines/engine[0]/opstateresp") == 4)
      {
         SetEngineState(0, 3);
      }
      if (getprop("/controls/engines/engine[1]/opstateresp") == 4)
      {
         SetEngineState(1, 3);
      }
      if (getprop("/controls/engines/engine[2]/opstateresp") == 4)
      {
         SetEngineState(2, 3);
      }
      if (getprop("/controls/engines/engine[3]/opstateresp") == 4)
      {
         SetEngineState(3, 3);
      }
   }
   if (getprop("/autopilot/locks/altitude") == "altitude-hold")
   {
       setprop("/fdm/jsbsim/crew/elevatorman/enabled", 1);
   }
   else
   {
       setprop("/fdm/jsbsim/crew/elevatorman/enabled", 0);
   }
   if (getprop("/autopilot/locks/heading") == "true-heading-hold")
   {
       setprop("/fdm/jsbsim/crew/helmsman/enabled", 1);
       var dK = getprop("/autopilot/settings/true-heading-deg");
       var aW = getprop("/environment/wind-from-heading-deg");
       var sW = getprop("/environment/wind-speed-kt");
       var dW = getprop("/velocities/airspeed-kt");
       if (dW != 0)
       {
	      var rK = (math.asin((math.sin((aW - dK) * D2R) * sW) / dW) * R2D) * 0.7;
          setprop("/fdm/jsbsim/crew/helmsman/heading-magnetic-cmd-deg", dK + rK);
       }
       else
       {
          setprop("/fdm/jsbsim/crew/helmsman/heading-magnetic-cmd-deg", getprop("/autopilot/settings/true-heading-deg"));
       }
   }
   else if (getprop("/autopilot/locks/heading") == "dg-heading-hold")
   {
       setprop("/fdm/jsbsim/crew/helmsman/enabled", 1);
   }
   else
   {
       setprop("/fdm/jsbsim/crew/helmsman/enabled", 0);
   }
}

var toggleLandingLight = func()
{
    if (getprop("/controls/lighting/landing-light") == 1)
    {
        setprop("/controls/lighting/landing-light", 0);
    }
    else
    {
        setprop("/controls/lighting/landing-light", 1);
    }
}

var toggleLight = func()
{
    if (getprop("/controls/lighting/panel-norm") == 1)
    {
        setprop("/controls/lighting/panel-norm", 0);
    }
    else
    {
        setprop("/controls/lighting/panel-norm", 1);
    }
}

var checkView = func()
{
    if (getprop("/sim/current-view/name") == "Bombsight View")
    {
        setprop("/sim/weapons/sightoff", 0);
        sight_timer.start();
    }
    else
    {
        sight_timer.stop();
        setprop("/sim/weapons/sightoff", 0);
    }
}

var updateBombSight = func()
{
    var h = getprop("/position/altitude-agl-ft") * 0.3048;
    var v = getprop("/velocities/groundspeed-kt") * 0.514444;
    var vorh = ((0.25674 / h) * ((math.sqrt((h * 2) / 9.81) * v) - 55)) / 2.0;
    setprop("/sim/weapons/sightoff", -vorh);
#    print("sight vorhalt " ~ vorh);
}

var EnableHelmsMan = func (state)
{
   setprop("/fdm/jsbsim/crew/helmsman/enabled" , state);
}

var selectNextBomb = func()
{
   var found = 0;
   for (var i = 0; i < 24; i = i + 1)
   {
      if ((getprop("/sim/weapons/bomb[" ~ i ~ "]/tobedropped") == 0) and (getprop("/sim/weapons/bomb[" ~ i ~ "]/dropped") == 0))
      {
         prepareBombs(i);
         found = 1;
         gui.popupTip("bomb selected");
         break;
      }
   }
   if (found == 0)
   {
      gui.popupTip("no more bombs available!");
   }
}

var prepareBombs = func(num)
{
   if (getprop("/sim/weapons/bomb[" ~ num ~ "]/tobedropped") == 0)
   {
      setprop("/sim/weapons/bomb[" ~ num ~ "]/tobedropped", 1);
   }
   else
   {
      setprop("/sim/weapons/bomb[" ~ num ~ "]/tobedropped", 0);
   }
}

var dropBombs = func()
{
   setprop("/sim/weapons/dropping", 1);
   settimer(dropBombsWork, 0.25);
}

var dropBombsWork = func()
{
   if (getprop("sim/model/door-positions/BDoor/position-norm") < 1)
   {
      gui.popupTip("open doors first.");
      setprop("/sim/weapons/dropping", 0);
      return;
   }
   if (getprop("/position/altitude-agl-ft") < 400)
   {
      gui.popupTip("altitude too low.");
      setprop("/sim/weapons/dropping", 0);
      return;
   }
   for (var i = 0; i < 24; i = i + 1)
   {
      if ((getprop("/sim/weapons/bomb[" ~ i ~ "]/tobedropped") == 1) and (getprop("/sim/weapons/bomb[" ~ i ~ "]/dropped") == 0))
      {
         setprop("/sim/weapons/bomb[" ~ i ~ "]/dropped", 1);
         setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[36]", getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[36]") - 220);
      }
   }
   gui.popupTip("bombs dropped.");
   setprop("/sim/weapons/dropping", 0);
}

var impactBomb = func(n)
{
   var node = props.globals.getNode(n.getValue(), 1);
   var impact = n.getValue();
   var solid = getprop(impact ~ "/material/solid");
   if (solid)
   {
      geo.put_model("Aircraft/SL11/Models/crater.xml",
           node.getNode("impact/latitude-deg").getValue(),
           node.getNode("impact/longitude-deg").getValue(),
           node.getNode("impact/elevation-m").getValue() + 0.1, # +0.25 to ensure the droptank isn't buried
           node.getNode("impact/heading-deg").getValue(),
       0, 0);
      geo.put_model("Aircraft/SL11/Models/bombe.xml",
           node.getNode("impact/latitude-deg").getValue(),
           node.getNode("impact/longitude-deg").getValue(),
           node.getNode("impact/elevation-m").getValue() + 0.25, # +0.25 to ensure the droptank isn't buried
           node.getNode("impact/heading-deg").getValue(),
       0, 0);
      start_terrain_fire(node.getNode("impact/latitude-deg").getValue(),
           node.getNode("impact/longitude-deg").getValue(),
           node.getNode("impact/elevation-m").getValue() + 0.25,
           230);
   }
}

setlistener("sim/ai/aircraft/impact/bomb", impactBomb);

################################################################################
#put_remove_model places a new model at the location specified and then removes
# it time_sec later 
#it puts out 12 models/sec so normally time_sec=.4 or thereabouts it plenty of time to let it run
# If time_sec is too short then no particles will be emitted.  Typical problem is 
# many rounds from a gun slow FG's framerate to a crawl just as it is time to emit the 
# particles.  If time_sec is slower than the frame length then you get zero particle.
# Smallest safe value for time_sec is maybe .3 .4 or .5 seconds.
# 
var put_remove_model = func(lat_deg=nil, lon_deg=nil, elev_m=nil, time_sec=nil, startSize_m=nil, endSize_m=1, path="Models/bombable/Fire-Particles/flack-impact.xml" ) {

  if (lat_deg==nil or lon_deg==nil or elev_m==nil) { return; } 
 
  var delay_sec=0.1; #particles/models seem to cause FG crash *sometimes* when appearing within a model
  #we try to reduce this by making the smoke appear a fraction of a second later, after
  # the a/c model has moved out of the way. (possibly moved, anyway--depending on it's speed)  

 # debprint ("Bombable: Placing flack");
         
  settimer ( func {
    #start & end size in particle system appear to be in feet
    if (startSize_m!=nil) setprop ("/bombable/fire-particles/flack-startsize", startSize_m);
    if (endSize_m!=nil) setprop ("/bombable/fire-particles/flack-endsize", endSize_m);

    fgcommand("add-model", flackNode=props.Node.new({ 
            "path": path, 
            "latitude-deg": lat_deg, 
            "longitude-deg":lon_deg, 
            "elevation-ft": elev_m / 0.3048,
            "heading-deg"  : 0,
            "pitch-deg"    : 0,
            "roll-deg"     : 0, 
            "enable-hot"   : 0,
  
            
              
    }));
    
  var flackModelNodeName= flackNode.getNode("property").getValue();
  
  #add the -prop property in /models/model[X] for each of lat, long, elev, etc
  foreach (name; ["latitude-deg","longitude-deg","elevation-ft", "heading-deg", "pitch-deg", "roll-deg"]){
   setprop(  flackModelNodeName ~"/"~ name ~ "-prop",flackModelNodeName ~ "/" ~ name );
  }  
  
#  debprint ("Bombable: Placed flack, ", flackModelNodeName);
  
  settimer ( func { props.globals.getNode(flackModelNodeName).remove();}, time_sec);

  }, delay_sec);   

}

##############################################################
#Start a fire on terrain, size depending on ballisticMass_lb
#location at lat/lon
#
var start_terrain_fire = func ( lat_deg, lon_deg, alt_m=0, ballisticMass_lb=1.2 ) {

  var info = geodinfo(lat_deg, lon_deg);
  var smokeEndsize = rand()*75+33;
  setprop ("/bombable/fire-particles/smoke-endsize-small", smokeEndsize);
  var smokeEndsize = rand()*125+60;
  setprop ("/bombable/fire-particles/smoke-endsize-large", smokeEndsize);
  var smokeStartsize=rand()*10 + 5;
  setprop ("/bombable/fire-particles/smoke-startsize", smokeStartsize);
  setprop ("/bombable/fire-particles/smoke-startsize-small", smokeStartsize * (rand()/2 + 0.5));
  setprop ("/bombable/fire-particles/smoke-startsize-very-small", smokeStartsize * (rand()/8 + 0.2));
  setprop ("/bombable/fire-particles/smoke-startsize-large", smokeStartsize* (rand()*4 + 1));
  #get the altitude of the terrain
  if (info != nil)
  {
      #if it's water we don't set a fire . . . TODO make a different explosion or fire effect for water 
      if (typeof(info[1])=="hash" and contains(info[1], "solid") and info[1].solid==0) return;
     # else debprint (info);
      
      #we go with explosion point if possible, otherwise the height of terrain at this point
      if (alt_m==nil) alt_m=info[0];
      if (alt_m==nil) alt_m=0; 
      
  }
  time_sec=150; 
  fp1="Models/bombable/Fire-Particles/fire-particles-large.xml";
  put_remove_model(lat_deg:lat_deg, lon_deg:lon_deg, elev_m:alt_m, time_sec:time_sec, startSize_m: nil, endSize_m:nil, path:fp1 );
  time_sec1=600; 
  fp="Models/bombable/Fire-Particles/smoke-particles-large.xml";
  put_remove_model(lat_deg:lat_deg, lon_deg:lon_deg, elev_m:alt_m, time_sec:time_sec1, startSize_m: nil, endSize_m:nil, path:fp );
  ##put it out, but slowly, for large impacts
  if (ballisticMass_lb>50)
  {
    time_sec2=150; fp2="Models/bombable/Fire-Particles/fire-particles-very-small.xml";  
    settimer (func { put_remove_model(lat_deg:lat_deg, lon_deg:lon_deg, elev_m:alt_m, time_sec:time_sec2, startSize_m: nil, endSize_m:nil, path:fp2 )} , time_sec);
    
    time_sec3=150; fp3="Models/bombable/Fire-Particles/fire-particles-very-very-small.xml";  
    settimer (func { put_remove_model(lat_deg:lat_deg, lon_deg:lon_deg, elev_m:alt_m, time_sec:time_sec3, startSize_m: nil, endSize_m:nil, path:fp3 )} , time_sec+time_sec2);
    
    time_sec4=150; fp4="Models/bombable/Fire-Particles/fire-particles-very-very-very-small.xml";  
    settimer (func { put_remove_model(lat_deg:lat_deg, lon_deg:lon_deg, elev_m:alt_m, time_sec:time_sec4, startSize_m: nil, endSize_m:nil, path:fp4 )} , time_sec+time_sec2+time_sec3);
  
  }

}
###############################################################################
# Utility functions

# Set up aTransfer fluid between two properties without losing or creating any.
#  amount [lb]
#  rate   [lb/sec]
var SmoothTransfer = {
    # Set up a smooth value transfer between two properties.
    #  from, to       : property paths or property nodes
    #  rate           : units/sec. MUST be positive.
    #  amount         : the amount to transfer. MUST be positive.
    #  stop_at_zero   : stop if the from property reaches 0.0.
    new: func(from, to, rate, amount=-1, stop_at_zero=1) {
        var m = { parents: [SmoothTransfer] };
        m.from         = aircraft.makeNode(from);
        m.to           = aircraft.makeNode(to);
        m.left         = amount;
        m.rate         = rate;
        m.stop_at_zero = stop_at_zero;
        m.last_time    = getprop("/sim/time/elapsed-sec");
        settimer(func{ m._loop_(); }, 0.0);
        return m;
    },
    stop: func {
        me.left = 0.0;
    },
    _loop_: func() {
        var t = getprop("/sim/time/elapsed-sec");
        var a = me.rate * (t - me.last_time);
        a = (a < me.left) ? a : me.left;
        if (me.stop_at_zero) {
            var f = me.from.getValue();
            a = (a < f) ? a : f;
        }
        me.from.setValue(f - a);
        me.to.setValue(me.to.getValue() + a);
        me.left -= a;
        me.last_time = t;
        if (me.left > 0.0) {
            settimer(func{ me._loop_(); }, 0.0);
        }
    }
};


###############################################################################
# Debug display - stand in instrumentation.
var debug_display_view_handler = {
    init : func {
        if (contains(me, "left")) return;

        me.left  = screen.display.new(20, 10);
        me.right = screen.display.new(-250, 20);
        # Static condition
        me.left.add("/fdm/jsbsim/static-condition/net-lift-lbs");
        me.left.add("/fdm/jsbsim/static-condition/static-pitch-moment-lbsft");
        # C.G.
        me.left.add("/fdm/jsbsim/inertia/cg-x-in");
        # Atmosphere and gas temperatures
        me.left.add("/environment/temperature-degc");
        me.left.add("/fdm/jsbsim/buoyant_forces/gas-cell[0]/temp-R",
                    "/fdm/jsbsim/buoyant_forces/gas-cell[1]/temp-R",
                    "/fdm/jsbsim/buoyant_forces/gas-cell[10]/temp-R",
                    "/fdm/jsbsim/buoyant_forces/gas-cell[11]/temp-R");
        # Pitch moments
        #me.left.add("/fdm/jsbsim/moments/m-buoyancy-lbsft",
        #            "/fdm/jsbsim/moments/m-aero-lbsft",
        #            "/fdm/jsbsim/moments/m-total-lbsft");
        # Mooring related
    #    me.left.add("/fdm/jsbsim/mooring/total-distance-ft",
    #                "/fdm/jsbsim/mooring/latitude-diff-ft",
    #                "/fdm/jsbsim/mooring/longitude-diff-ft",
    #                "/fdm/jsbsim/mooring/altitude-diff-ft");
        #me.left.add("/fdm/jsbsim/velocities/vrp-v-north-fps",
        #            "/velocities/speed-north-fps");
        #me.left.add("/fdm/jsbsim/velocities/vrp-v-east-fps",
        #            "/velocities/speed-east-fps");
        #me.left.add("/fdm/jsbsim/velocities/vrp-v-down-fps",
        #            "/velocities/speed-down-fps");

        # Flight information
        me.right.add("orientation/pitch-deg");
        me.right.add("surface-positions/elevator-pos-norm");
        me.right.add("surface-positions/rudder-pos-norm");
        me.right.add("instrumentation/altimeter/indicated-altitude-ft");
        me.right.add("instrumentation/airspeed-indicator/indicated-speed-kt");
        me.right.add("instrumentation/magnetic-compass/indicated-heading-deg");
        # Engines
        me.right.add("/engines/engine[0]/rpm",
                     "/engines/engine[1]/rpm",
                     "/engines/engine[2]/rpm",
                     "/engines/engine[3]/rpm",
         #            "/fdm/jsbsim/propulsion/engine[0]/power-hp",
         #            "/fdm/jsbsim/propulsion/engine[1]/power-hp",
         #            "/fdm/jsbsim/propulsion/engine[2]/power-hp",
         #            "/fdm/jsbsim/propulsion/engine[3]/power-hp",
                     "/controls/engines/engine[0]/mixture",
                     "/controls/engines/engine[1]/mixture",
                     "/controls/engines/engine[2]/mixture",
                     "/controls/engines/engine[3]/mixture",
                     "/controls/engines/engine[0]/throttle",
                     "/controls/engines/engine[1]/throttle",
                     "/controls/engines/engine[2]/throttle",
                     "/controls/engines/engine[3]/throttle"
                     );

        me.shown = 1;
        me.stop();
    },
    start  : func {
        if (!me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 1;
    },
    stop   : func {
        if (me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 0;
    }
};

# Install the debug display for some views.
#setlistener("/sim/signals/fdm-initialized", func {
#    view.manager.register("Watch Officer View", debug_display_view_handler);
#    view.manager.register("Rudder Man View", debug_display_view_handler);
#    view.manager.register("Elevator Man View", debug_display_view_handler);
#    print("Debug instrumentation ... check");
#});

###############################################################################
# fake part of the electrical system.
var fake_electrical = func {
#    setprop("systems/electrical/ac-volts", 24);
#    setprop("systems/electrical/volts", 24);

#    setprop("/systems/electrical/outputs/comm[0]", 24.0);
#    setprop("/systems/electrical/outputs/comm[1]", 24.0);
#    setprop("/systems/electrical/outputs/nav[0]", 24.0);
#    setprop("/systems/electrical/outputs/nav[1]", 24.0);
#    setprop("/systems/electrical/outputs/dme", 24.0);
#    setprop("/systems/electrical/outputs/adf", 24.0);
#    setprop("/systems/electrical/outputs/transponder", 24.0);
#    setprop("/systems/electrical/outputs/instrument-lights", 24.0);
#    setprop("/systems/electrical/outputs/gps", 24.0);
#    setprop("/systems/electrical/outputs/efis", 24.0);

#    setprop("/instrumentation/clock/flight-meter-hour",0);

    var beacon_switch =
        props.globals.initNode("controls/lighting/beacon", 1, "BOOL");
    var beacon = aircraft.light.new("sim/model/lights/beacon",
                                    [0.05, 1.2],
                                    "/controls/lighting/beacon");
    var strobe_switch =
        props.globals.initNode("controls/lighting/strobe", 1, "BOOL");
    var strobe = aircraft.light.new("sim/model/lights/strobe",
                                    [0.05, 3],
                                    "/controls/lighting/strobe");
}
###############################################################################

###########################################################################
## MP integration of user's fixed local mooring locations.
## NOTE: Should this be here or elsewhere?
#settimer(func { mp_network_init(1); }, 0.1);

###############################################################################
# About dialog.

var ABOUT_DLG = 0;

var dialog = {
#################################################################
    init : func (x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[1.0, 1.0, 1.0, 1.0]]; 
        #
        # "private"
        me.title = "About";
        me.dialog = nil;
        me.namenode = props.Node.new({"dialog-name" : me.title });
    },
#################################################################
    create : func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.Widget.new();
        me.dialog.set("name", me.title);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");
        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set
            ("label",
             "About");
        var w = titlebar.addChild("button");
        w.set("pref-width", 16);
        w.set("pref-height", 16);
        w.set("legend", "");
        w.set("default", 0);
        w.set("key", "esc");
        w.setBinding("nasal", "SL11.dialog.destroy(); ");
        w.setBinding("dialog-close");
        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "vbox");
        content.set("halign", "center");
        content.set("default-padding", 5);
        props.globals.initNode("sim/about/text",
             "Schuette-Lanz SL 11 airship for FlightGear\n" ~
             "Copyright (C) 2017  Franz Schmid\n\n" ~
             "Copyright (C) 2010 - 2016  Anders Gidenstam\n\n" ~
             "FlightGear flight simulator\n" ~
             "Copyright (C) 1996 - 2016  http://www.flightgear.org\n\n" ~
             "This is free software, and you are welcome to\n" ~
             "redistribute it under certain conditions.\n" ~
             "See the GNU GENERAL PUBLIC LICENSE Version 2 for the details.",
             "STRING");
        var text = content.addChild("textbox");
        text.set("halign", "fill");
        #text.set("slider", 20);
        text.set("pref-width", 400);
        text.set("pref-height", 300);
        text.set("editable", 0);
        text.set("property", "sim/about/text");

        #me.dialog.addChild("hrule");

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.namenode);
    },
#################################################################
    close : func {
        fgcommand("dialog-close", me.namenode);
    },
#################################################################
    destroy : func {
        ABOUT_DLG = 0;
        me.close();
        delete(gui.dialog, "\"" ~ me.title ~ "\"");
    },
#################################################################
    show : func {
        if (!ABOUT_DLG) {
            ABOUT_DLG = 1;
            me.init(400, getprop("/sim/startup/ysize") - 500);
            me.create();
        }
    }
};
###############################################################################

# Popup the about dialog.
var about = func {
    dialog.show();
}
###############################################################################
## Ground party.

var ground_crew = {
    ##################################################
    init : func {
        me.UPDATE_INTERVAL = 0.42;
        me.loopid = 0;
        # There are two handling guy parties.
        me.position = geo.aircraft_position();
        me.pos = [geo.aircraft_position(), geo.aircraft_position()];
        me.connected =
            [props.globals.getNode
             ("/fdm/jsbsim/landing-party/wire-connected[0]"),
             props.globals.getNode
             ("/fdm/jsbsim/landing-party/wire-connected[1]")];
        me.wire_length =
            props.globals.getNode("/fdm/jsbsim/landing-party/wire-length-ft");
        me.model = {local : [nil, nil]};
        me.wind_heading =
            props.globals.getNode("/environment/wind-from-heading-deg");
        me.active = 0;

#        if (props.globals.getNode("/sim/presets/onground").getValue()) {
            me.active = 1;
            me.connected[0].setValue(0.99);
            me.connected[1].setValue(0.99);
#        }
        me.reset();
        print("Ground crew ... Standing by.");
    },
    ##################################################
    # Place the ground crew.
    place_ground_crew : func (pos, heading=nil, altitude=nil, name="local") {
        if (heading == nil) {
            me.heading = me.wind_heading.getValue();
        } else {
            me.heading = heading;
        }
        me.position = pos;
        me.pos[0].set(pos);
        me.pos[1].set(pos);
        me.pos[0].apply_course_distance(me.heading - 45.0, 20.0);
        me.pos[1].apply_course_distance(me.heading + 45.0, 20.0);
        if (altitude == nil) {
            me.pos[0].set_alt(geodinfo(me.pos[0].lat(), me.pos[0].lon())[0]);
            me.pos[1].set_alt(geodinfo(me.pos[1].lat(), me.pos[1].lon())[0]);
        } else {
            me.pos[0].set_alt(altitude);
            me.pos[1].set_alt(altitude);
        }  
        print("ground_crew: Handling parties at ");
        me.pos[0].dump(); me.pos[1].dump();

        setprop("/fdm/jsbsim/landing-party/latitude-deg[0]", me.pos[0].lat());
        setprop("/fdm/jsbsim/landing-party/longitude-deg[0]", me.pos[0].lon());
        setprop("/fdm/jsbsim/landing-party/altitude-ft[0]",
                me.pos[0].alt() * M2FT);
        setprop("/fdm/jsbsim/landing-party/latitude-deg[1]", me.pos[1].lat());
        setprop("/fdm/jsbsim/landing-party/longitude-deg[1]", me.pos[1].lon());
        setprop("/fdm/jsbsim/landing-party/altitude-ft[1]",
                me.pos[1].alt() * M2FT);
    
        if (me.model.local[0] != nil) me.model.local[0].remove();
        if (me.model.local[1] != nil) me.model.local[1].remove();
        me.model.local[0] = geo.put_model
            (getprop("/sim/aircraft-dir") ~ "/Models/GroundCrew/wire-party.xml",
             me.pos[0], me.heading + 135.0);
        me.model.local[1] = geo.put_model
            (getprop("/sim/aircraft-dir") ~ "/Models/GroundCrew/wire-party.xml",
             me.pos[1], me.heading - 135.0);
     #   broadcast.send(message_id["place_ground_crew"] ~
     #                  Binary.encodeCoord(me.pos[0]) ~
     #                  Binary.encodeCoord(me.pos[1]) ~
     #                  Binary.encodeDouble(me.heading));
    },
    ##################################################
    place_remote_ground_crew : func (key, pos1, pos2, heading) {
        if (!contains(me.model, key)) me.model[key] = [nil, nil];

        if (me.model[key][0] != nil) me.model[key][0].remove();
        if (me.model[key][1] != nil) me.model[key][1].remove();
        me.model[key][0] = geo.put_model
            (getprop("/sim/aircraft-dir") ~ "/Models/GroundCrew/wire-party.xml",
             pos1, heading + 135.0);
        me.model[key][1] = geo.put_model
            (getprop("/sim/aircraft-dir") ~ "/Models/GroundCrew/wire-party.xml",
             pos2, heading - 135.0);
    },
    ##################################################
    remove_remote_ground_crew : func (key) {
        if (!contains(me.model, key)) return;
        if (me.model[key][0] != nil) me.model[key][0].remove();
        if (me.model[key][1] != nil) me.model[key][1].remove();
    },
    ##################################################
    let_go : func {
        if (me.connected[0].getValue() or me.connected[1].getValue())
            me.announce("Handling guys released!");
        me.active = 0;
        me.connected[0].setValue(0.0);
        me.connected[1].setValue(0.0);
        me.wire_length.setValue(650.0);
    },
    ##################################################
    activate : func {
        me.active = 1;
        me.wire_length.setValue(650.0);
        me.place_ground_crew(me.position);
        me.announce("Ready for landing!");
    },
    ##################################################
    announce : func(msg) {
        setprop("/sim/messages/ground", msg);
    },
    ##################################################
    update : func {
        if (!me.active) return;
        
        if ((me.connected[0].getValue() < 1.0) and
            (getprop("/fdm/jsbsim/landing-party/total-distance-ft[0]") <
             2.0*getprop("/fdm/jsbsim/landing-party/wire-length-ft"))) {
            me.connected[0].setValue(1.0);
            me.announce("Left handling guy secured!");
        }
        if ((me.connected[1].getValue() < 1.0) and
            (getprop("/fdm/jsbsim/landing-party/total-distance-ft[1]") <
             2.0*getprop("/fdm/jsbsim/landing-party/wire-length-ft"))) {
            me.connected[1].setValue(1.0);
            me.announce("Right handling guy secured!");
        }
        if ((me.connected[0].getValue() >= 0.99) and
            (me.connected[1].getValue() >= 0.99) and
            (me.wire_length.getValue() == 650.0)) {
            interpolate(me.wire_length, 40.0, 30.0);
        }
    },
    ##################################################
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    ##################################################
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
    }
};

setlistener("/sim/signals/fdm-initialized", func {
    ground_crew.init();
    ground_crew.place_ground_crew(geo.aircraft_position(),
                                  getprop("/orientation/heading-deg"));

    setlistener("/sim/signals/click", func {
        var click_pos = geo.click_position();
        if (__kbd.ctrl.getBoolValue()) {
            SL11.ground_crew.place_ground_crew(click_pos,
                                                         nil,
                                                         click_pos.alt());
        }
    });
});

var weather_dialog = gui.Dialog.new("/sim/gui/dialogs/sl11/weather/dialog", "Aircraft/SL11/Dialogs/weather-report.xml");
var autopilot_dialog = gui.Dialog.new("sim/gui/dialogs/autopilot/dialog", "Aircraft/SL11/Dialogs/autopilot.xml");

