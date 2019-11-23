import re

# Color coding makes it easier to read
CDEFLT = "ffffff"
COLOR = {
	# Special
	"NonColor": "101010",
	"LowColor": "1a1a1a",
	
	# Factional
	"Global Changes": "7c7c7c",
	"ISDF": "ff6c00",
	"Scion": "797b98",
	"Hadean": "a69677",
	"Daedlian": "79987b",
	
	# Weapons
	"Mortars": "5858b0",
	"Missiles": "f47a00",
	"Guns": "cc00cc",
	"Cannons": "00a9cc",
	"Specials": "f40000",
	"Mines": "f40000",
	"Shields": "caca00",
	"Pilot Weapons": "cccccc",
	
	# Other
	"Maps": "ffff00",
	"DLL": "00c129",
	"Shell": "c10091",
	"Default":CDEFLT
}

# Author dictionary
AUTHDFLT = "Unknown Author"
AUTHOR = {
	"ZA": "Zero Angel",
	"MT": "Mortarion",
	"RL": "Rush Limbaugh",
	"GB": "General BlackDragon",
	"CD": "Community Decision",
	"??": AUTHDFLT
}

# Armor class icons
ARMOR_CLASS = {
	"N": "i.imgur.com/PXGk1DD.png",
	"L": "i.imgur.com/tKy3Q45.png",
	"H": "i.imgur.com/hJjFOAw.png",
	"S": "i.imgur.com/uC9PmLd.png",
	"D": "i.imgur.com/FaFwqfC.png",
	"A": "i.imgur.com/9SyRzA9.png"
}

# Lines to ignore. e.g. comments
re_ignore = re.compile(r"\s*//")
# [1] Tabs [2] Content
re_entry = re.compile(r"(\t*)(.+)")
# [1] Section Name
re_section = re.compile(r"\[([^\]]+)\]")
# [1] Ref ID [2] Short Author [3] Content
re_documented_change = re.compile(r"\{VSR-(...)-(..)\} (.+)")
# [1] Damage type name [2] Data
re_damage = re.compile(r"DMG:([^ ]+) (.+)")
# [1] Armor class [2] Damage
re_dmgclass = re.compile(r"\[(.)\](.+?%)")

# Subsequent levels of indentation will fade in color
def Brighten(hex_string, step = 38):
	c = [0, 0, 0]
	for i in range(3):
		c[i] = max(0, min(255, int(hex_string[i*2:i*2+2], 16)+step))
	return "%02x%02x%02x" % (c[0], c[1], c[2])

# To allow same syntax for printing or writing to file
class PRINT:
	def write(self, data, end=""):
		print(data, end=end)

# Print BB code for phpBB release thread
def CompileBB(fl_read, out = PRINT()):
	# Color-at-indentation-level
	color = [CDEFLT]
	
	# Styles
	main_font_size = 120
	SPACER = "-"
	SECTION = "[size=%d][b]%%s[/b][/size]" % main_font_size
	ENTRY = "[*][color=#%s]%s[/color]"
	IND_START, IND_END = "[list]", "[/list]"
	
	# Begin
	out.write(IND_START + "\n")
	level = -1
	prev_level = 0
	for line in fl_read:
		if not line or re_ignore.match(line):
			continue
		
		match = re_entry.match(line)
		if not match:
			continue
		
		level = len(match.group(1))
		entry = match.group(2)
		
		# Indentation level
		if level > prev_level:
			out.write(IND_START + "\n") 
		elif level < prev_level:
			# Space primary sections
			for i in range(max(0, 2-level)):
				out.write("[color=#%s][size=%d]%s[/size][/color]" % (COLOR["NonColor"], main_font_size, SPACER*1) + "\n")
			
			for i in range(prev_level - level):
				out.write(IND_END + "\n")
				del color[-1]
		prev_level = level
		
		# Section?
		match = re_section.match(entry)
		if match:
			name = match.group(1)
			color += [COLOR[name] if name in COLOR else color[-1]]
			
			# Brighten subsequent identical colors
			if len(color) > 2 and color[-1] == color[-2]:
				color[-1] = Brighten(color[-1])
			
			out.write(ENTRY % (color[-1], SECTION % name) + "\n")
			continue
		
		# Documented change?
		match = re_documented_change.match(entry)
		if match:
			ref = match.group(1)
			author = AUTHOR[match.group(2)]
			info = match.group(3)
			
			match = re_damage.match(info)
			if match:
				name = match.group(1)
				data = match.group(2)
				
				info = "%s damage: " % name
				for armor, value in re_dmgclass.findall(data):
					info += "[img]http://%s[/img]%s " % (ARMOR_CLASS[armor], value)
				out.write(ENTRY % (color[-1], info) + "\n")
			else:
				out.write(
					ENTRY % (color[-1], info) +
					" [size=85][color=#%s]Ref #%s -%s[/color][/size]" % (
						COLOR["LowColor"], ref, author
					+ "\n")
				)
			
			continue
		
		# Other (e.g. DLL feature, map change)
		out.write(ENTRY % (color[-1], entry))
	out.write(IND_END*2)

# Print simple ascii version for changelog and installer
def CompileAscii(fl_read, out = PRINT()):
	# Begin
	level = -1
	prev_level = 0
	for line in fl_read:
		if not line or re_ignore.match(line):
			continue
		
		match = re_entry.match(line)
		if not match:
			continue
		
		level = len(match.group(1))
		entry = match.group(2)
		indentation = "  " * level
		
		# Section?
		match = re_section.match(entry)
		if match:
			if level <= 0:
				out.write("\n")
			
			out.write("%s* %s:\n" % (indentation, match.group(1)))
			
			continue
		
		# Documented change?
		match = re_documented_change.match(entry)
		if match:
			ref = match.group(1)
			author = AUTHOR[match.group(2)]
			info = match.group(3)
			
			match = re_damage.match(info)
			if match:
				name = match.group(1)
				data = match.group(2)
				
				info = "%s damage: " % name
				for armor, value in re_dmgclass.findall(data):
					info += "[%s]%s " % (armor, value)
			out.write("%s%s\n" % (indentation, info))
			continue
		
		# Other (e.g. DLL feature, map change)
		out.write("%s%s\n" % (indentation, entry))

if __name__ == "__main__":
	with open("./Changes.devtxt", "r") as devtxt:
		CompileBB(devtxt)
	
	with open("./Changes.devtxt", "r") as devtxt:
		with open("./VSR 6.0 Changes.txt", "w") as outputvsrtxt:
			CompileAscii(devtxt, outputvsrtxt)
