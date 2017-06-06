import os
import glob
import json
import argparse
import configparser
import genXML

def doMain() :
	parser = argparse.ArgumentParser(description='Parser for ECLDOC')
	parser.add_argument('--config', help="Specify configuration file")
	args = parser.parse_args()

	cfgparser = configparser.ConfigParser()
	cfgparser.read(args.config)

	if 'INPUT' in cfgparser.sections() :
		input_root = os.path.realpath(cfgparser['INPUT']['root'])
		if 'include' in cfgparser['INPUT'] :
			include = json.loads(cfgparser['INPUT']['include'])
		if 'exclude' in cfgparser['INPUT'] :
			exclude = json.loads(cfgparser['INPUT']['exclude'])

	ecl_files = []
	for pattern in include :
		filenames = glob.glob(input_root + pattern, recursive=True)
		filenames = [os.path.realpath(f) for f in filenames]
		ecl_files += [os.path.relpath(f, input_root) for f in filenames]


	for pattern in exclude :
		filenames = glob.glob(input_root + pattern, recursive=True)
		filenames = [os.path.realpath(f) for f in filenames]
		filenames = [os.path.relpath(f, input_root) for f in filenames]
		ecl_files = list(set(ecl_files) - set(filenames))

	if 'OUTPUT' in cfgparser.sections() :
		output_root = cfgparser['OUTPUT']['root']
		if not os.path.exists(output_root) :
			os.makedirs(output_root, exist_ok=True)

		genXML.genXML(input_root, output_root, ecl_files)


if __name__ == '__main__' :
	doMain()
