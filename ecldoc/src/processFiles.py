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
    cfgparser.optionxform = str
    cfgparser.read(args.config)

    ecl_files = []
    options = {'eclcc' : []}
    if 'INPUT' in cfgparser.sections() :
        input_root = os.path.realpath(cfgparser['INPUT']['root'])
        options['nodoc'] = cfgparser['INPUT'].getboolean('hideNodoc', False)
        options['nointernal'] = cfgparser['INPUT'].getboolean('hideInternal', False)

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

    if 'ECLCC' in cfgparser.sections() :
        for key in cfgparser['ECLCC'] :
            options['eclcc'].append(key)

    print(options)

    if 'OUTPUT' in cfgparser.sections() :
        output_root = cfgparser['OUTPUT']['root']
        if not os.path.exists(output_root) :
            os.makedirs(output_root, exist_ok=True)

        xmlgenerator = genXML.GenXML(input_root, output_root, ecl_files, options)
        xmlgenerator.genXML()
        ecl_file_tree = xmlgenerator.ecl_file_tree
        genHTML.GenHTML(input_root, output_root, ecl_file_tree, options).genHTML()
        genTXT.GenTXT(input_root, output_root, ecl_file_tree, options).genTXT()
        #genTEX.GenTEX(input_root, output_root, ecl_file_tree, options).genTEX()

if __name__ == '__main__' :
    doMain()
