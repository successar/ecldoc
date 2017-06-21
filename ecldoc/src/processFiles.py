import os
import glob
import json
import argparse
import configparser
import genXML, genHTML

def doMain() :
    parser = argparse.ArgumentParser(description='Parser for ECLDOC')
    parser.add_argument('--config', help="Specify configuration file")
    args = parser.parse_args()

    cfgparser = configparser.ConfigParser()
    cfgparser.read(args.config)

    ecl_files = []
    if 'INPUT' in cfgparser.sections() :
        input_root = os.path.realpath(cfgparser['INPUT']['root'])

        include = []
        if 'include' in cfgparser['INPUT'] :
            include = [x.strip() for x in cfgparser['INPUT']['include'].split(',')]
        else :
            include = ['**/*.ecl']

        for pattern in include :
            pattern = os.path.join(input_root, pattern)
            filenames = glob.glob(pattern, recursive=True)
            filenames = [os.path.realpath(f) for f in filenames]
            ecl_files += [os.path.relpath(f, input_root) for f in filenames]

        if 'exclude' in cfgparser['INPUT'] :
            exclude = [x.strip() for x in cfgparser['INPUT']['exclude'].split(',')]
            for pattern in exclude :
                pattern = os.path.join(input_root, pattern)
                filenames = glob.glob(pattern, recursive=True)
                filenames = [os.path.realpath(f) for f in filenames]
                filenames = [os.path.relpath(f, input_root) for f in filenames]
                ecl_files = list(set(ecl_files) - set(filenames))

    if 'OUTPUT' in cfgparser.sections() :
        output_root = cfgparser['OUTPUT']['root']
        if not os.path.exists(output_root) :
            os.makedirs(output_root, exist_ok=True)

        genXML.genXML(input_root, output_root, ecl_files)
        genHTML.GenHTML(input_root, output_root, ecl_files).genHTML()


if __name__ == '__main__' :
    doMain()
