
#include "modules/base.sp" /* DO NOT DELETE/MODIFY THIS LINE */

#include "modules/tank.sp"
#include "modules/armoredcar.sp"
#include "modules/ambulance.sp"

#include "modules/kingpanzer.sp"
#include "modules/panzer3.sp"
#include "modules/marder3.sp"

/*
At the beginning of the round, only infantry like soldiers, engies, and officers will be available.
to commission more vehicles, engineers must build various vehicle spawn bases which act as the spawn points for vehicles.

any player who walks into those vehicle spawn bases will be transformed as those vehicles or they can change class at the infantry spawn as the vehicles as soon as the vehicle spawn is finished building



Tank powerup mode: normal tf2 game but with tanks added in as powerups. random ammo packs (maybe even healthpacks) will have tank powerups on top of them. Optionally, engineers can build vehicles using alot of metal.
Ambulance - 600 metal
Armored car - 2k metal
Panzer 3 - 3k metal
Panzer 4 - 4k metal
Marder 3 - 3k metal
King Panzer - 5k metal

IDEAS:

~add 'drifting' or movement de-acceleration to vehicles

Spy tank interaction
if spy stabs tank
	tank takes 100 dmg,
	glow for 15 seconds,
	and is marked for death for 15 seconds
If marked for death, increase damage taken by 2x

only allow vehicles to be built near a garage

have spies be able to disguise as tanks in terms of speed, model, and sound

encourage custom maps
make tanks larger
make garages act as vehicle spawn points

add tank construct limits to certain constructs
1 tiger, 3 panzers, 3 howitzer panzers, 4 armored cars, 2 ambulances, 1 marder 2
*/
