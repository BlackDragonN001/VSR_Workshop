version = 1.00

import re

thumbnail_name = "%s.dds" #"%s_vsrthmb.dds"
simple_filter = "VSR"

header_height = 30
size = (840, 480 - (header_height + 15))

class Tile:
	def __init__(self, bzn_name, full_name):
		self.bzn = bzn_name
		self.full_name = full_name
		self.name = full_name.split(": ")[-1]
		self.tags = full_name.split(": ")[0:-1]
	
	def __lt__(self, other):
		return self.name < other.name

def write_config(label, tiles = []):
	tiles_per_row = 13
	tiles_per_column = 6
	tile_size = 64
	tile_index = 0
	
	pages = round(len(tiles) / (tiles_per_row * tiles_per_column) + 0.5)
	
	for page in range(pages):
		with open("%s%d.cfg" % (label, page), "w") as cfg:
			if page == 0:
				cfg.write("ConfigureInterface() {\n")
				cfg.write("\tDefineColorGroup('MAP_TILE_COLOR') {\n")
				cfg.write("\t\tForeground(0, 255, 255, 255, 255);\n")
				cfg.write("\t\tBackground(0, 200, 200, 200, 255);\n")
				cfg.write("\t\tGradient(0, 200, 200, 200, 255);\n")
				cfg.write("\t\tForeground(1, 255, 255, 255, 255);\n")
				cfg.write("\t\tBackground(1, 200, 200, 200, 255);\n")
				cfg.write("\t\tGradient(1, 200, 200, 200, 255);\n")
				cfg.write("\t\tForeground(2, 255, 255, 255, 255);\n")
				cfg.write("\t\tBackground(2, 255, 255, 255, 255);\n")
				cfg.write("\t\tGradient(2, 255, 255, 255, 255);\n")
				cfg.write("\t\tForeground(3, 255, 255, 255, 200);\n")
				cfg.write("\t\tBackground(3, 255, 255, 255, 200);\n")
				cfg.write("\t\tGradient(3, 255, 255, 255, 200);\n")
				cfg.write("\t}\n")
				cfg.write("}\n\n")
				
				for i in range(1, pages):
					cfg.write("Exec('%s%d.cfg');\n" % (label, i))
				
				cfg.write("\n")
			
			cfg.write("CreateControl('%s%d', 'WINDOW') {\n" % (label, page))
			cfg.write("\tGeom('PARENTWIDTH', 'PARENTHEIGHT');\n")
			cfg.write("\tBevelSize(1);\n\n")
			cfg.write("\tColorGroup('LISTBOX');\n\n")
			
			# Players Window
			cfg.write("\tCreateControl('Players', 'WINDOW') {\n")
			cfg.write("\t\tColorGroup('MAGENTA');\n")
			cfg.write("\t\tStyle('OUTLINE', 'TABROOT', 'INERT');\n")
			cfg.write("\t\tTitle('Players');\n")
			cfg.write("\t\tTitleFont('SMALL');\n")
			cfg.write("\t\tPos(10, %d);\n" % (header_height // 2 + 4))
			cfg.write("\t\tSize(190, %d);\n" % (header_height // 2))
			cfg.write("\t\tBorderSize(5);\n")
			cfg.write("\t\tBevelSize(5);\n")
			cfg.write("\t\tTabSize(60, 10);\n\n")
			
			# Slider
			cfg.write("\t\tCreateControl('PlayerCountSlider', 'SLIDER') {\n")
			cfg.write("\t\t\tColorGroup('BLACKBLUE');\n")
			cfg.write("\t\t\tSize(100, 9);\n")
			cfg.write("\t\t\tBorderSize(3);\n")
			cfg.write("\t\t\tBevelSize(3);\n")
			cfg.write("\t\t\tStyle('ROLLOVER');\n")
			cfg.write("\t\t\tPos(0, 3);\n")
			cfg.write("\t\t\tUseVar('network.session.ivar2');\n")
			cfg.write("\t\t\tRange(1, 14);\n")
			cfg.write("\t\t}\n\n")
			
			# Set To 10 Players Button
			cfg.write("\t\tCreateControl('OpenPlayerCount', 'BUTTON') {\n")
			cfg.write("\t\t\tColorGroup('BLACKBLUE');\n")
			cfg.write("\t\t\tStyle('ROLLOVER', 'RADIO', 'OUTLINE');\n")
			cfg.write("\t\t\tGeom('VCENTER');\n")
			cfg.write("\t\t\tFont('TINY');\n")
			cfg.write("\t\t\tText('10');\n")
			cfg.write("\t\t\tUseVar('network.session.ivar2');\n")
			cfg.write("\t\t\tValue(10);\n")
			cfg.write("\t\t\tPos(125, 0);\n")
			cfg.write("\t\t\tSize(19, 9);\n")
			cfg.write("\t\t\tBorderSize(3);\n")
			cfg.write("\t\t\tBevelSize(3);\n")
			cfg.write("\t\t}\n\n")
			
			# Edit
			cfg.write("\t\tCreateControl('EditPlayerCount', 'EDIT') {\n")
			cfg.write("\t\t\tColorGroup('BLACKBLUE');\n")
			cfg.write("\t\t\tGeometry('LEFT','VCENTER');\n")
			cfg.write("\t\t\tPosition(160, 0);\n")
			cfg.write("\t\t\tSize(26, 9);\n")
			cfg.write("\t\t\tBorderSize(3);\n")
			cfg.write("\t\t\tBevelSize(3);\n")
			cfg.write("\t\t\tJustifyText('CENTER');\n")
			cfg.write("\t\t\tFont('TINY');\n")
			cfg.write("\t\t\tStyle('ROLLOVER', 'OUTLINE');\n")
			cfg.write("\t\t\tCursor('Highlight');\n")
			cfg.write("\t\t\tUseVar('network.session.ivar2');\n")
			cfg.write("\t\t}\n\n")
			
			cfg.write("\t}\n\n")
			
			# Page Control Window
			cfg.write("\tCreateControl('PageControl', 'WINDOW') {\n")
			cfg.write("\t\tGeom('HCENTRE', 'TOP');\n")
			cfg.write("\t\tPos(0, 4);\n")
			cfg.write("\t\tSize(128, 32);\n")
			cfg.write("\t\tStyle('OUTLINE', 'TRANSPARENT');\n\n")
			
			# Previous Page Button
			if page > 0:
				cfg.write("\t\tCreateControl('PreviousPage','BUTTON') {\n")
				cfg.write("\t\t\tColorGroup('MAGENTA');\n")
				cfg.write("\t\t\tGeom('LEFT','VCENTRE');\n")
				cfg.write("\t\t\tSize(24, 24);\n")
				cfg.write("\t\t\tBorderSize(2);\n")
				cfg.write("\t\t\tBevelSize(2);\n")
				cfg.write("\t\t\tStyle('OUTLINE', 'ROLLOVER');\n")
				cfg.write("\t\t\tCursor('Highlight');\n")
				cfg.write("\t\t\tNotifyParent('Button::Press', 'PreviousPage');\n")
				cfg.write("\t\t\tText('<--');\n")
				cfg.write("\t\t\tFont('LARGE');\n")
				cfg.write("\t\t\tStyle('ROLLOVER', 'OUTLINE');\n")
				cfg.write("\t\t}\n\n")

				cfg.write("\t\tOnEvent('PreviousPage') {\n")
				cfg.write("\t\t\tDeactivate('|%s%d');\n" % ((label, page)))
				cfg.write("\t\t\tActivate('|%s%d');\n" % ((label, page - 1)))
				cfg.write("\t\t}\n\n")

			# Page Text
			cfg.write("\t\tCreateControl('WhatPage','STATIC') {\n")
			cfg.write("\t\t\tGeom('HCENTRE', 'VCENTRE');\n")
			cfg.write("\t\t\tSize(130, 14);\n")
			cfg.write("\t\t\tText('Page %d/%d');\n" % (page + 1, pages))
			cfg.write("\t\t\tFont('MEDIUM');\n")
			cfg.write("\t\t\tStyle('INERT', 'TRANSPARENT');\n")
			cfg.write("\t\t}\n\n")
			
			# Next Page Button
			if page + 1 < pages:
				cfg.write("\t\tCreateControl('NextPage','BUTTON') {\n")
				cfg.write("\t\t\tColorGroup('MAGENTA');\n")
				cfg.write("\t\t\tGeom('RIGHT','VCENTRE');\n")
				cfg.write("\t\t\tSize(24, 24);\n")
				cfg.write("\t\t\tBorderSize(2);\n")
				cfg.write("\t\t\tBevelSize(2);\n")
				cfg.write("\t\t\tStyle('OUTLINE', 'ROLLOVER');\n")
				cfg.write("\t\t\tCursor('Highlight');\n")
				cfg.write("\t\t\tNotifyParent('Button::Press', 'NextPage');\n")
				cfg.write("\t\t\tText('-->');\n")
				cfg.write("\t\t\tFont('LARGE');\n")
				cfg.write("\t\t\tStyle('ROLLOVER', 'OUTLINE');\n")
				cfg.write("\t\t}\n\n")

				cfg.write("\t\tOnEvent('NextPage') {\n")
				cfg.write("\t\t\tDeactivate('|%s%d');\n" % ((label, page)))
				cfg.write("\t\t\tActivate('|%s%d');\n" % ((label, page + 1)))
				cfg.write("\t\t}\n")
			
			cfg.write("\t}\n\n")
			
			# X Close Button
			cfg.write("\tCreateControl('Close','BUTTON') {\n")
			cfg.write("\t\tColorGroup('MAGENTA');\n")
			cfg.write("\t\tGeom('RIGHT', 'TOP');\n")
			cfg.write("\t\tPos(-8, 8);\n")
			cfg.write("\t\tSize(24, 24);\n")
			cfg.write("\t\tBorderSize(2);\n")
			cfg.write("\t\tBevelSize(2);\n")
			cfg.write("\t\tFont('LARGE');\n")
			cfg.write("\t\tText('X');\n")
			cfg.write("\t\tStyle('ROLLOVER', 'OUTLINE', 'BLINK');\n")
			cfg.write("\t\tNotifyParent('Button::Press', 'Close');\n\n")
			cfg.write("\t}\n\n")
			cfg.write("\tOnEvent('Close') {\n")
			cfg.write("\t\tDeactivate('|%s%d');\n" % ((label, page)))
			cfg.write("\t}\n\n")
			
			# Map Tiles
			cfg.write("\tCreateControl('Tiles','WINDOW') {\n")
			cfg.write("\t\tColorGroup('BACKGROUND');\n")
			cfg.write("\t\tGeom('HCENTRE', 'VCENTRE');\n")
			cfg.write("\t\tPos(0, %d);\n" % (header_height // 2))
			cfg.write("\t\tBorderSize(2);\n")
			cfg.write("\t\tSize(%d, %d);\n" % (tiles_per_row * (tile_size + 1), tiles_per_column * (tile_size + 1)))
			for y in range(tiles_per_column):
				for x in range(tiles_per_row):
					tile_index += 1
					if tile_index >= len(tiles):
						break
					
					tile = tiles[tile_index]
					
					cfg.write("\n\t\tCreateControl('Tile','BUTTON') {\n")
					cfg.write("\t\t\tColorGroup('MAP_TILE_COLOR');\n")
					cfg.write("\t\t\tPos(%d, %d);\n" % (x * (tile_size + 1), y * (tile_size + 1)))
					cfg.write("\t\t\tSize(%d, %d);\n" % (tile_size, tile_size))
					cfg.write("\t\t\tStyle('ROLLOVER');\n")
					cfg.write("\t\t\tNotifyParent('Button::Press', 'Set%d');\n" % tile_index)
					cfg.write("\t\t\tImage('%s', 0, 0, 256, 256);\n\n" % (thumbnail_name % tile.bzn))
					
					cfg.write("\t\t\tCreateControl('Text','STATIC') {\n")
					cfg.write("\t\t\t\tGeom('PARENTWIDTH', 'BOTTOM');\n")
					cfg.write("\t\t\t\tColorGroup('MAGENTA');\n")
					cfg.write("\t\t\t\tBevelSize(1);\n")
					cfg.write("\t\t\t\tStyle('INERT');\n")
					cfg.write("\t\t\t\tFont('TINY');\n")
					cfg.write("\t\t\t\tText(\"%s\");\n" % tile.name)
					cfg.write("\t\t\t\tSize(0, 10);\n")
					cfg.write("\t\t\t}\n\n")
					
					cfg.write("\t\t}\n\n")
					
					cfg.write("\t\tOnEvent('Set%d') {\n" % tile_index)
					cfg.write("\t\t\tCmd('network.session.svar0 %s.bzn');\n" % tile.bzn)
					cfg.write("\t\t\tCmd('network.session.closeextras');\n")
					cfg.write("\t\t}\n")
			cfg.write("\t}\n")
			
			cfg.write("}\n")

def tiles_from_file(file_path):
	re_entry = re.compile(r"([^ ]+)\.bzn \(([^\)]+)\).+?[\r\n]+")
	
	with open(file_path, "r") as txt:
		for bzn, name in re_entry.findall(txt.read()):
			yield Tile(bzn, name)

if __name__ == "__main__":
	tiles = list(tiles_from_file("VSR_Maps.txt"))
	
	# Only include VSR maps
	tiles = [tile for tile in tiles if simple_filter in tile.full_name]
	tiles.sort()
	
	write_config("VSR_MapTiles", tiles)
