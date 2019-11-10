#!/usr/bin/python

maps_directory = "./"
output_file = "MapThumbs/VSR_Maps.txt"
#~ maps_directory = "C:/MyGames/BZ2/NewestPatch/vsr-alpha/missions/Multiplayer/VSR Maps"
#~ output_file = "./MapThumbs/VSR Maps.txt"

import os
import re
import math

reMsnName = re.compile(r"(?i)\s*missionName\s*=\s*\"([^\"]+)\"")

def get_inf_map_name(filePath):
	fl = open(filePath, "r")
	for ln in fl:
		match = re.match(reMsnName, ln)
		if match:
			return match.group(1)
	fl.close()
	return ""

reBznGameObj = re.compile(r"\s*\[GameObject]")
reBznObj = re.compile(r"(?:config|GetClass\(\)|objClass)\s*=\s*(.+)") # Any bzn object odf type declaration.
reBznPos = re.compile(r"\s*posit\.([xyz]) \[1\]\s*=")
reBznVal = re.compile(r"\s*([\-\+]?[\d]+\.?[\d]*)")
reBznSpawnLabel = re.compile(r"\s*label\s*=\s*([^ ]+)")

# Returns the average distance between player spawns.
def get_bzn_map_data(filePath):
	type_other = 0
	type_spawn = 1
	type_scrap = 2
	type_playerspawn = 3
	
	scrap_value = {"npscrx":5,"npscr1":5,"npscr2":5,"npscr3":5}
	scrap_normal = 0
	scrap_respawning = 0
	spawns = []
	xFound = False
	zFound = False
	
	inODF = None
	fl = open(filePath, "r")
	for ln in fl:
		# Find odf config.
		if inODF is None:
			match = re.match(reBznObj, ln)
			if match:
				odf = match.group(1).lower()
				#~ print("\t%r"%odf)
				if odf == "pspwn_1":
					spawns += [[match.group(1), 0, 0]]
					inODF = type_playerspawn
				elif odf == "spawn":
					inODF = type_spawn
				elif odf in scrap_value:
					scrap_normal += scrap_value[odf]
					inODF = type_scrap # Doesn't really matter as the work is done here.
				else:
					inODF = type_other
		else:
			# In "pspwn_1":
			if inODF == type_playerspawn:
				match = re.match(reBznPos, ln)
				if match:
					if match.group(1) == "x":
						xFound = True
					elif match.group(1) == "z":
						zFound = True
				elif xFound or zFound:
					match = re.match(reBznVal, ln)
					if match:
						if xFound:
							spawns[-1][1] += float(match.group(1))
							xFound = False
						elif zFound:
							spawns[-1][2] += float(match.group(1))
							zFound = False
			
			# In "spawn":
			elif inODF == type_spawn:
				match = re.match(reBznSpawnLabel, ln)
				if match:
					spawn_config = "_".join(match.group(1).lower().split("_")[0:-1])
					if spawn_config in scrap_value:
						scrap_respawning += scrap_value[spawn_config]
			
			# Beginning of new object?
			if re.match(reBznGameObj, ln):
				inODF = None
	fl.close()
	
	average = 0
	if spawns:
		for spwn in spawns:
			average += math.sqrt(spwn[1]**2+spwn[2]**2)
		average /= len(spawns)
	
	return scrap_normal, scrap_respawning, abs(round(average))

bzn, inf = {}, {}
for root, dirs, files in os.walk(maps_directory):
	for file in files:
		if file[-4::].lower() == ".bzn":
			bzn[file[0:-4].lower()] = os.path.join(root, file)
		elif file[-4::].lower() == ".inf":
			inf[file[0:-4].lower()] = os.path.join(root, file)

# Do single test map.
#~ # for bz2map in bzn:
#~ bz2map = "stmagmavsr"
#~ if True:
	#~ print(bzn[bz2map])
	#~ name = get_inf_map_name(inf[bz2map])
	#~ scrap_normal, scrap_respawning, base_distance = get_bzn_map_data(bzn[bz2map])
	#~ print("Name: %r" % name)
	#~ print("Base Distance: %d" % base_distance)
	#~ print("Scrap: %d (%d respawning)" % (scrap_normal, scrap_respawning))
	#~ # break


# Do all maps in the specified directory.
fl = open(output_file, "w")
count = len(bzn)
for ind, bz2map in enumerate(bzn):
	print("%d/%d: %s..." % (ind+1, count, bz2map))
	name = get_inf_map_name(inf[bz2map])
	scrap_normal, scrap_respawning, base_distance = get_bzn_map_data(bzn[bz2map])
	fl.write("%s.bzn (%s) [%d] [%d] [%d]\n" % (bz2map, name, scrap_normal, scrap_respawning, base_distance))
fl.close()
