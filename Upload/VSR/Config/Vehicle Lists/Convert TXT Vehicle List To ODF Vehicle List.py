#!/usr/bin/python
# Note: Always use forward slashes in python for file paths, even in windows.

def ConvertVehicleList(filePathIn, filePathOut = ""):
	if not filePathOut:
		filePathOut = filePathIn
	fileName = filePathIn.split("/")[-1]
	print("Input file:", fileName)
	
	# Read old file...
	fl = open(filePathIn, "r")
	# item[*] = [XSI, ODF, Description]
	items = []
	for ln in fl:
		item = ln[0:-1].split(" ", 2)
		if len(item) > 2:
			items += [[item[0], item[1], item[2]]]
	fl.close()
	
	# Write new file...
	fl = open(filePathOut, "w")
	fl.write("[%s]\n" % fileName[0:-4])
	for index, item in enumerate(items):
		fl.write("xsi%d=\"%s\"\ncfg%d=\"%s\"\nDescription%d=\"%s\"\n\n" % (
		1+index, item[0],
		1+index, item[1],
		1+index, item[2]
		))
	fl.close()

import sys

if len(sys.argv) >= 3:
	ConvertVehicleList(sys.argv[1], sys.argv[2])
elif len(sys.argv) == 2:
	ConvertVehicleList(sys.argv[1], sys.argv[1])
else:
	print("No input parameters found.")