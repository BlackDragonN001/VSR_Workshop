#!/usr/bin/python

# This script can be used to contemplate potential asset conflicts
# if VSR were to be put into an uncontained environment.
import os, re

# STRINGS MUST BE UPPERCASE
manual_whitelist = (
	"DARKFOX HADEAN CHANGES.TXT",
	"DESKTOP.INI",
)

# STRINGS MUST BE UPPERCASE
names_must_contain_atleast_one_of_these = (
	"VSR",
	"_HADEAN", # Hadean vehicle dmg
	"DAED",    # Daedlian prefix
	"ZSN",     # e.g. sniper forest
)

# Load ignored extensions from devnote file
ignore_ext = []
re_ext = re.compile("\s*\*\.(.+)")
try:
	with open("./Ignore Ext.devtxt", "r") as fl:
		for ln in fl:
			match = re_ext.match(ln)
			if match:
				ignore_ext += [match.group(1).upper()]
except:
	print("Warning: 'Ignore Ext.devtxt' not found in CWD.")

def ok(fname):
	fupper = fname.upper()
	
	if fupper in manual_whitelist:
		return True
	
	fext = fname.split(".")[-1].upper()
	if fext in ignore_ext:
		return True
	
	for test in names_must_contain_atleast_one_of_these:
		if test in fupper:
			return True
	
	return False

if __name__ == "__main__":
	fail = []
	for root, dirs, files in os.walk("./"):
		for file in files:
			if not ok(file):
				fail += [os.path.join(root, file)]

	print("%d files do not have unique names:" % len(fail))
	for f in fail:
		print(f)

	input("Press ENTER to exit.")
