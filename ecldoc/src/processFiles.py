import os
import glob
import argparse
import configparser
import genXML, genHTML, genTXT, genTEX

def doMain() :
    parser = argparse.ArgumentParser(description='Parser for ECLDOC')
    parser.add_argument('--config', help="Specify configuration file")
    args = parser.parse_args()

    cfgparser = configparser.ConfigParser()
    cfgparser.read(args.config)

    ecl_files = []
    options = {}
    if 'INPUT' in cfgparser.sections() :
        input_root = os.path.realpath(cfgparser['INPUT']['root'])
        options['nodoc'] = cfgparser['INPUT'].getboolean('showNodoc', False)
        print(options['nodoc'])
        options['internal'] = cfgparser['INPUT'].getboolean('showInternal', False)

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

        #genXML.GenXML(input_root, output_root, ecl_files, options).genXML()
        #genHTML.GenHTML(input_root, output_root, ecl_files, options).genHTML()
        #genTXT.GenTXT(input_root, output_root, ecl_files, options).genTXT()
        genTEX.GenTEX(input_root, output_root, ecl_files, options).genTEX()

if __name__ == '__main__' :
    doMain()
