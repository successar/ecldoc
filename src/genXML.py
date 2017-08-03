import os
import re
import json
import subprocess
from copy import deepcopy

from lxml import etree
from lxml.builder import E

from Utils import genPathTree
from Utils import joinpath, relpath, dirname, realpath
from Utils import read_file

from parseDoc import parseDocstring, cleansign, breaksign


class ParseXML(object):
    def __init__(self, generator, ecl_file):
        self.input_root = generator.input_root
        self.output_root = generator.output_root
        self.ecl_file = ecl_file
        self.xml_root = generator.xml_root
        self.xml_orig_root = generator.xml_orig_root

        self.input_file = joinpath(self.input_root, ecl_file)
        self.xml_orig_file = joinpath(self.xml_orig_root, ecl_file + '.xml')
        self.xml_file = joinpath(self.xml_root, ecl_file + '.xml')
        self.xml_dir = dirname(self.xml_file)

        self.options = generator.options
        self.internal = False
        self.generator = generator

        #local
        self.depends = {}
        self.src = None

    def parse(self):
        os.makedirs(dirname(self.xml_orig_file), exist_ok=True)
        eclcc_options = ' '.join(self.options['eclcc'])
        p = subprocess.call(['eclcc -M ' + eclcc_options +
                             ' -o ' + self.xml_orig_file + ' ' +
                             self.input_file], shell=True, cwd=self.input_root)
        print("ECLCC ||| File : ", self.ecl_file, " ||| Output Code : ", p)

        tree = etree.parse(self.xml_orig_file)
        root = tree.getroot()

        for src in root.iter('Source'):
            attribs = src.attrib
            srcpath = realpath(attribs['sourcePath'])

            if os.path.exists(srcpath) and srcpath.startswith(self.input_root):
                attribs['sourcePath'] = srcpath
                src_relpath = relpath(srcpath, self.input_root)
                tgtpath = joinpath(self.xml_root, (src_relpath + '.xml'))
                tgtpath = realpath(tgtpath)
                tgtpath = relpath(tgtpath, self.xml_dir)
                attribs['target'] = tgtpath
                if src_relpath == self.ecl_file:
                    continue

            root.remove(src)
            depend = etree.Element('Depends', sourcePath=attribs['sourcePath'])

            if 'name' in attribs:
                depend.set('name', attribs['name'])
                self.depends[tuple(attribs['name'].lower().split('.'))] = depend

            if 'target' in attribs:
                depend.set('target', attribs['target'])
            else:
                if 'name' in attribs:
                    matched = self.generator.matchExdoc(attribs['name'], source=attribs['sourcePath'])
                    if matched is not None:
                        depend.set('target', matched + '.xml')
                    else:
                        depend.set('target', attribs['sourcePath'])
                else:
                    depend.set('target', attribs['sourcePath'])

            root.insert(-1, depend)

        self.src = root.find('Source')
        self.parseSource()
        if len(self.src.findall('Definition')) == 0:
            self.internal = True

        if self.internal is False:
            os.makedirs(dirname(self.xml_file), exist_ok=True)
            tree.write(self.xml_file, xml_declaration=True, encoding='utf-8')

    def parseSource(self):
        attribs = self.src.attrib
        srcpath = realpath(attribs['sourcePath'])
        self.text = read_file(srcpath)

        if 'name' in attribs:
            self.depends[tuple(attribs['name'].lower().split('.'))] = self.src

        for imp in self.src.iter('Import'):
            self.parseImport(imp)

        for doc in self.src.iter('Documentation'):
            self.parseDocumentation(doc)

        for defn in self.src.findall('Definition'):
            if self.checkDefinition(defn):
                self.src.remove(defn)
            else:
                self.parseDefinition(defn)

        maindefn = self.src.find("Definition")
        if maindefn is not None and maindefn.find('Documentation') is not None:
            docstring = deepcopy(maindefn.find('Documentation'))
            self.src.append(docstring)
        else:
            self.src.append(E('Documentation', E('content', ' ')))

    def parseDefinition(self, defn):
        attribs = defn.attrib
        self.generateSignature(defn)

        if 'fullname' in attribs:
            fullname = attribs['fullname']
            best_depend = self.matchPath(fullname)
            if best_depend is not None and best_depend != self.src:
                attribs['target'] = best_depend.attrib['target']
        elif 'name' in attribs:
            attribs['fullname'] = 'ecldoc-' + attribs['name']

        for childdefn in defn.findall('Definition'):
            if attribs['inherittype'] == 'inherited' or self.checkDefinition(childdefn):
                defn.remove(childdefn)
            else:
                self.parseDefinition(childdefn)

        parents = defn.find('Parents')
        if parents is not None:
            self.parseParents(parents)

        attribs.pop('body', None)
        attribs.pop('start', None)
        attribs.pop('end', None)

    def generateSignature(self, defn):
        attribs = defn.attrib
        name = attribs['name']
        is_scope = 'type' in attribs and attribs['type'] in ['module', 'interface']
        has_params = defn.find('Params') is not None

        ecl_text = self.text
        gen_sign = False

        if 'fullname' in attribs:
            gen_sign = True
            if is_scope and (not has_params) :
                gen_sign = False
            else :
                best_depend = self.matchPath(attribs['fullname'])
                if best_depend is not None and best_depend != self.src:
                    ecl_text = read_file(best_depend.attrib['sourcePath'])

        sign = etree.Element('Signature')
        sign.text = name
        if gen_sign and ('start' in attribs) and ('body' in attribs) :
            sign.text = ecl_text[int(attribs['start']):int(attribs['body'])]
            sign.text = cleansign(sign.text)

        ret, param, indent_len = breaksign(name, sign.text)

        sign.attrib['name'] = name
        sign.attrib['ret'] = ret
        sign.attrib['param'] = param
        sign.attrib['hlen'] = str(indent_len)
        defn.insert(-1, sign)

    def parseDocumentation(self, doc):
        content = doc.find('content')
        elements = parseDocstring(content.text)
        doc.remove(content)
        for tag in elements:
            for desc in elements[tag]:
                doc.append(desc)

    def parseImport(self, imp):
        attribs = imp.attrib
        if 'ref' in attribs:
            attribs['target'] = self.matchReference(attribs['ref'])

        attribs.pop('body', None)
        attribs.pop('start', None)
        attribs.pop('end', None)
        attribs.pop('fullname', None)
        attribs.pop('line', None)
        attribs.pop('inherittype', None)
        if imp.find('Documentation') is not None :
            imp.remove(imp.find('Documentation'))

    def parseParents(self, parents):
        for parent in parents.findall('Parent'):
            attribs = parent.attrib
            if 'ref' in attribs:
                attribs['target'] = self.matchReference(attribs['ref'])

    def matchReference(self, refpath):
        target = ''
        best_depend = self.matchPath(refpath)
        if best_depend is not None:
            target = best_depend.attrib['target']
        else:
            matched = self.generator.matchExdoc(refpath)
            if matched is not None:
                target = matched + '.xml'
            else:
                refpath = refpath.split('.') + ['pkg.toc.xml']
                target = joinpath(self.xml_root, *refpath)
                target = relpath(target, self.xml_dir)
        return target

    def matchPath(self, path):
        path = tuple(path.lower().split('.'))
        current_prefix = ()
        for depend_path in self.depends:
            prefix = os.path.commonprefix([path, depend_path])
            if len(prefix) > len(current_prefix):
                current_prefix = prefix

        if len(current_prefix) > 0 and current_prefix in self.depends:
            return self.depends[current_prefix]

        return None

    def checkDefinition(self, defn):
        test_1 = 'exported' not in defn.attrib
        test_2 = self.options['nodoc'] and (defn.find('Documentation') is None)
        test_3 = (self.options['nointernal'] and
                  (defn.find('Documentation') is not None) and
                  (defn.find('Documentation').find('internal') is not None))
        return test_1 or test_2 or test_3

###########################################################################################

def parseBundle(generator, ecl_file):
    input_file = joinpath(generator.input_root, ecl_file)
    dirpath = dirname(input_file)

    dirpath_xml_orig = dirname(joinpath(generator.xml_orig_root, ecl_file))
    dirpath_xml = dirname(joinpath(generator.xml_root, ecl_file))

    bundle_orig_path = joinpath(dirpath_xml_orig, 'bundle.orig.out')
    bundle_xml_path = joinpath(dirpath_xml, 'bundle.xml')

    os.makedirs(dirpath_xml_orig, exist_ok=True)
    p = subprocess.call(['ecl-bundle info ' + dirpath + ' > ' + bundle_orig_path], shell=True)
    print("Output Code : ", p, "Bundle File : ", dirpath)

    data = read_file(bundle_orig_path).split('\n')
    data = [x.split(':', 1) for x in data]
    data = [(x[0].strip(), x[1].strip()) for x in data if len(x) == 2]
    root = etree.Element("Bundle")
    for k in data:
        node = etree.Element(k[0])
        node.text = k[1]
        root.append(node)

    os.makedirs(dirname(bundle_xml_path), exist_ok=True)
    etree.ElementTree(root).write(bundle_xml_path, pretty_print=True, xml_declaration=True, encoding='utf-8')

###########################################################################################

class GenXML(object):
    def __init__(self, input_root, output_root, ecl_files, options):
        self.input_root = input_root
        self.output_root = output_root
        self.ecl_file_tree = genPathTree(ecl_files)
        self.options = options

        self.xml_orig_root = joinpath(output_root, 'xmlOriginal')
        os.makedirs(self.xml_orig_root, exist_ok=True)

        self.xml_root = joinpath(output_root, 'xml')
        os.makedirs(self.xml_root, exist_ok=True)

    def gen(self, key, node, xml_root, content_root):
        if type(node[key]) != dict:
            if key == 'bundle.ecl':
                parseBundle(self, node[key])
                return
            ecl_file = node[key]
            parser = ParseXML(self, ecl_file)
            parser.parse()
            if parser.internal:
                del node[key]
            else:
                file = etree.Element('file')
                file.attrib['name'] = key + '.xml'
                file.text = node[key]
                xml_root.append(file)
        else:
            child = node[key]
            folder = etree.Element('folder')
            xml_root.append(folder)
            folder.attrib['name'] = key

            keys = list(child.keys())
            for chkey in keys:
                child_root = joinpath(content_root, chkey)
                self.gen(chkey, child, folder, child_root)

            os.makedirs(content_root, exist_ok=True)
            toc_file = joinpath(content_root, 'pkg.toc.xml')
            etree.ElementTree(folder).write(toc_file, pretty_print=True, xml_declaration=True, encoding='utf-8')
            self.genJsonTree(child, content_root)

    def run(self):
        print("\nGenerating XML Documentation ... ")
        self.processExternalDoc()
        root = etree.Element('Root')
        self.gen('root', self.ecl_file_tree, root, self.xml_root)

    #######################################################################
    # Generate tree for files and subfolders in each folder for given run #
    # Currently used by External Dodc matching system .                   #
    #######################################################################

    def genJsonTree(self, tree, output_path='', dump=True):
        json_output = {}
        new_tree = deepcopy(tree)
        self.processJsonTree(new_tree)
        json_output['tree'] = new_tree
        json_output['output_root'] = self.output_root
        json_output['input_root'] = self.input_root
        if dump:
            json.dump(json_output, open(joinpath(output_path, 'tree.json'), 'w'), sort_keys=True, indent=4)

        return json_output

    def processJsonTree(self, tree):
        keys = list(tree.keys())
        for key in keys:
            if type(tree[key]) == dict:
                self.processJsonTree(tree[key])
            node = tree[key]
            del tree[key]
            tree[re.sub(r'\.ecl$', '', key.lower())] = {'key': key, 'tree': node}

    ###############################################################
    # Process External Docs and provide match function for parser #
    ###############################################################

    def processExternalDoc(self):
        self.exdocs = []
        currdoc = self.genJsonTree(self.ecl_file_tree['root'], dump=False)
        self.exdocs.append(currdoc)
        for path in self.options['exdoc_paths']:
            json_file = joinpath(path, 'tree.json')
            assert os.path.isfile(json_file), ("Exdoc file does not exists : " + json_file)
            external_doc = json.load(open(json_file))
            self.exdocs.append(external_doc)

    def matchExdoc(self, fullname, source=''):
        fullname = tuple(fullname.lower().split('.'))
        matched = None
        for exdoc in self.exdocs:
            val = self.findInTree(fullname, exdoc['tree'], '')
            if val is not None:
                if source == '' or realpath(source).startswith(exdoc['input_root']):
                    matched = joinpath(exdoc['output_root'], '$$_ECLDOC-FORM_$$', val)
                    break
        return matched

    def findInTree(self, fullname, tree, child_root):
        if type(tree) == dict:
            if len(fullname) == 0: return joinpath(child_root, 'pkg.toc')
            if fullname[0] in tree:
                return self.findInTree(fullname[1:],
                                       tree[fullname[0]]['tree'],
                                       joinpath(child_root, tree[fullname[0]]['key']))
            return None

        return tree
