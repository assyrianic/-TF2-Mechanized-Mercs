
#include "modules/base.sp" /* DO NOT DELETE/MODIFY THIS LINE */

#include "modules/tank.sp"
#include "modules/armoredcar.sp"
#include "modules/ambulance.sp"

#include "modules/kingpanzer.sp"
#include "modules/panzer3.sp"
#include "modules/marder3.sp"

/*
IDEAS

Scout - Armored Car
Soldier - general infantry - give 4th wep slot
Pyro - Light, Flamethrower Tank

Demoman - Panzer 4 Tank
Heavy - King Tiger 2 Tank
Engineer - builds sentries and fixes vehicles; armed with a 4th weapon - defensive stickybomb launcher to help fight off vehicle assaults
		Sentries take a long time to build but have 1000 default hp

Medic - Medical vehicle that heals players near it. Carry teammates. moves faster then armored car, has smg weapon but unarmored
Sniper - Tank Destroyer - Marder 3.

Spy - Officer with accurate revolvers = players near the officer-spy will gain buffs like minicrits or defense buff; replace ambassador with enforcer, melee will be whip. Replace sapper with pistol and buff main ammo to 150


At the beginning of the round, only infantry like soldiers, engies, and officers will be available.
to commission more vehicles, engineers must build various vehicle spawn bases which act as the spawn points for vehicles.

any player who walks into those vehicle spawn bases will be transformed as those vehicles or they can change class at the infantry spawn as the vehicles as soon as the vehicle spawn is finished building


rocket launchers. - 1 rocket clip, 10 reserve ammo, longer reload : 1.5 sec, 50%+ damage increase for rockets, rockets are inaccurate.
have engineers hitting bases make them build faster

Tank powerup mode: normal tf2 game but with tanks added in as powerups. random ammo packs (maybe even healthpacks) will have tank powerups on top of them. Optionally, engineers can build vehicles using alot of metal.
Ambulance - 600 metal
Armored car - 2k metal
Panzer 3 - 3k metal
Panzer 4 - 4k metal
Marder 3 - 3k metal
King Panzer - 5k metal

IDEAS:

~have appropriate bases slowly heal and rearm (act as lvl 1 dispensers) the respective vehicles they unlock.
~add 'drifting' or movement de-acceleration to vehicles
~have officer melee aid in building structures
~gun game mode: everybody starts as armored car, earn kills to unlock the classes. Armored Car can capture, self-heal. Change the Panzer 3 flamethrower to something else for this mode.
-be able to exit free build vehicles

1 - support vehicles - builds the fastest
~Armored Car - 2-3 hits
~Medical Vehicle - 1-2 hits

2 - offense vehicles
~Light Tank - 3-4 hits
~Panzer 4 Tank - 4-5 hits

3 - heavy support vehicles - builds the slowest
~King Tiger II tank - 5-6 hits
~Tank Destroyer - 2-3 hits

*/
