TORNADO MINE [Created by Zero Angel]

Dispenses a timed mine that disrupts and gradually damages mobile units.

PURPOSE:

To provide the ability to disrupt enemy forces during such purposes as base raiding, rushing, breaking
assault formations, or even defense; In essence, this fills nearly the same purpose as MITS, but on 
a much larger scale, and because it is so powerful, the user will be required to build another once
one is used up.

ADDTIONAL NOTES AND CAVEATS:

- This may be fitted to a spraybomb if remote launching is desired
- The tornado outputs physical (as opposed to energy) damage, so deflection shields are more effective.
- I have tried to balance this weapon somewhat, but anyone else may adjust the final balance of this
	weapon if it is needed. Please note that I do not want the duration of the tornado lowered
	because I think it would be better if it had an 'effect' where in MP the commander can see
	his unit icons flash as they take damage, then arrive to the scene to see them in the
	grip of the tornado. It has less of a dramatic effect if the units are destroyed too quickly.
- I wanted to have the mine have an effect where it shoots a ray of light into the sky at the center 
	of the cloud, but I couldn't get it to work.


MANIFEST

aptornad.odf: 	Powerup Box
aptornad.inf: 	Description file for Tornado Mine Powerup
gtornad.odf:	The actual tornado dispenser, localammo to 200 to ensure that only one can be used
tornadomn.odf:	The tornado mine itself, when placed it waits 4 seconds before starting the tornado.
tornadomn.inf:	Description file for Tornado Mine. If you get close enough to read it, then you'll
		probably be dead soon. :-)
tgale.odf:	The ordnance fired by the tornado mine. Pulseshell class uses small explosions to suck
		any enemies into it.
tornademit.odf:	This is the 'emit', or 'pulse' that tgale uses to suck units in. Also damages units.
xtornhit.odf:	The hit explosion of tgale.odf. This explosion will not hit often due to the negative
		shotradius used by tgale.odf.
xtorncloud.odf:	The tornado's 'cloud'. In actuality, it is the expire explosion of tgale.odf and creates
		additional suction while also damaging units caught in the tornado.
igtorn00.xsi:	Simply a boltmine model with an emit hardpoint added.
turbo1b.wav:	The sound of an aircraft taking off, it is the closest sound that I could find for the
		effect I want to create. Feel free to change it.