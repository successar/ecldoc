#!/usr/bin/env python3

import os
import glob
import argparse
import configparser
from Utils import joinpath, relpath, realpath
import genXML, genHTML, genTXT, genTEX

def split(arg, sep, apply=lambda x : x) :
    return [apply(x.strip()) for x in arg.split(sep) if len(x) != 0]

generators = {
    'html' : genHTML.GenHTML,
    'text' : genTXT.GenTXT,
    'pdf'  : genTEX.GenTEX
}

def configParser(configfile, options) :
    cfgparser = configparser.ConfigParser()
    cfgparser.optionxform = str
    cfgparser.read(configfile)

    options['input_root'] = None
    if 'INPUT' in cfgparser.sections() :
        options['input_root'] = realpath(cfgparser['INPUT']['root'])
        options['nodoc'] = cfgparser['INPUT'].getboolean('hideNodoc', False)
        options['nointernal'] = cfgparser['INPUT'].getboolean('hideInternal', False)

        include = ['**/*.ecl']
        if 'include' in cfgparser['INPUT'] :
            include = split(cfgparser['INPUT']['include'], sep=',')
        options['include'] = include

        exclude = []
        if 'exclude' in cfgparser['INPUT'] :
            exclude = split(cfgparser['INPUT']['exclude'], sep=',')
        options['exclude'] = exclude

    options['output_root'] = None
    options['formats'] = ['html', 'text', 'pdf']#, 'pdf']
    if 'OUTPUT' in cfgparser.sections() :
        options['output_root'] = cfgparser['OUTPUT']['root']
        if 'format' in cfgparser['OUTPUT'] :
            options['formats'] = split(cfgparser['OUTPUT']['format'], sep=',', apply=lambda x : x.lower())

    options['eclcc'] = []
    if 'ECLCC' in cfgparser.sections() :
        for key in cfgparser['ECLCC'] :
            options['eclcc'].append(key)

    options['exdoc_paths'] = []
    if 'EXDOC' in cfgparser.sections() :
        paths = split(cfgparser['EXDOC']['paths'], sep=',')
        options['exdoc_paths'] = paths

def argsParser(args, options) :
    options['input_root'] = args.iroot
    options['output_root'] = args.oroot
    options['include'] = split(args.include, ',')
    options['exclude'] = split(args.exclude, ',')
    options['eclcc'] = split(args.eclcc, ';')
    options['nodoc'] = args.hideNoDoc
    options['nointernal'] = args.hideInternal
    options['exdoc_paths'] = split(args.exdocpaths, ',', apply=lambda x : realpath(x))
    options['formats'] = split(args.format, ',', apply=lambda x : x.lower())

def doMain() :
    parser = argparse.ArgumentParser(description='Parser for ECLDOC')
    parser.add_argument('--config', help="Specify configuration file")
    parser.add_argument('-i', '--iroot', help="Specify input root")
    parser.add_argument('-o', '--oroot', help="Specify output root")
    parser.add_argument('-f', '--format', help="Specify output formats separated by , (eg html,text,pdf)", default='text')
    parser.add_argument('--include', help="Specify include paths", default='**/*.ecl')
    parser.add_argument('--exclude', help="Specify exclude paths", default='')
    parser.add_argument('--eclcc', help="Specify eclcc Options", default='')
    parser.add_argument('--exdocpaths', help="Specify External Documentation paths", default='')
    parser.add_argument('--hideNoDoc', help="Hide Definitions with No Documentation", action='store_true', default=False)
    parser.add_argument('--hideInternal', help="Hide Definitions with @internal tag", action='store_true', default=False)
    args = parser.parse_args()
    print(args)

    options = {}
    if args.config is not None :
        configParser(args.config, options)
    else :
        argsParser(args, options)

    assert options['input_root'] is not None
    assert options['output_root'] is not None
    print(options)

    ecl_files = []
    input_root = realpath(options['input_root'])
    for pattern in options['include'] :
        pattern = joinpath(input_root, pattern)
        filenames = glob.glob(pattern, recursive=True)
        filenames = [realpath(f) for f in filenames]
        ecl_files += [relpath(f, input_root) for f in filenames]

    for pattern in options['exclude'] :
        pattern = joinpath(input_root, pattern)
        filenames = glob.glob(pattern, recursive=True)
        filenames = [realpath(f) for f in filenames]
        filenames = [relpath(f, input_root) for f in filenames]
        ecl_files = list(set(ecl_files) - set(filenames))


    output_root = realpath(options['output_root'])
    if not os.path.exists(output_root) :
        os.makedirs(output_root, exist_ok=True)

    xmlgenerator = genXML.GenXML(input_root, output_root, ecl_files, options)
    xmlgenerator.run()
    ecl_file_tree = xmlgenerator.ecl_file_tree

    for f in options['formats'] :
        if f in generators :
            generators[f](input_root, output_root, ecl_file_tree, options).run()

if __name__ == '__main__' :
    doMain()
