import os
import re
import subprocess
import json
from copy import deepcopy

from lxml import etree
from lxml.builder import E
from Utils import genPathTree

from parseDoc import parseDocstring
from Utils import breaksign

class ParseXML(object) :
    def __init__(self, generator, ecl_file) :
        self.input_root = generator.input_root
        self.output_root = generator.output_root
        self.ecl_file = ecl_file
        self.xml_root = generator.xml_root
        self.xml_orig_root = generator.xml_orig_root

        self.input_file = os.path.join(self.input_root, ecl_file)
        self.xml_orig_file = os.path.join(self.xml_orig_root, ecl_file + '.xml')
        self.xml_file = os.path.join(self.xml_root, ecl_file + '.xml')
        self.xml_dir = os.path.dirname(self.xml_file)

        self.options = generator.options
        self.internal = False
        self.generator = generator


    def parse(self) :
        os.makedirs(os.path.dirname(self.xml_orig_file), exist_ok=True)
        eclcc_options = ' '.join(self.options['eclcc'])
        p = subprocess.call(['~/eclcc -M ' + eclcc_options +
                            ' -o ' + self.xml_orig_file + ' ' +
                            self.input_file], shell=True, cwd=self.input_root)
        print("File : ", self.input_file, "Output Code : ", p)

        tree = etree.parse(self.xml_orig_file)
        root = tree.getroot()

        self.depends = {}

        for src in root.iter('Source') :
            attribs = src.attrib
            srcpath = os.path.realpath(attribs['sourcePath'])

            if os.path.exists(srcpath) and srcpath.startswith(self.input_root):
                attribs['sourcePath'] = srcpath
                relpath = os.path.relpath(srcpath, self.input_root)
                tgtpath = os.path.join(self.xml_root, (relpath + '.xml'))
                tgtpath = os.path.realpath(tgtpath)
                tgtpath = os.path.relpath(tgtpath, self.xml_dir)
                attribs['target'] = tgtpath
                if relpath == self.ecl_file :
                    continue

            root.remove(src)
            depend = etree.Element('Depends', sourcePath=attribs['sourcePath'])

            if 'name' in attribs :
                depend.set('name', attribs['name'])
                self.depends[tuple(attribs['name'].lower().split('.'))] = depend

            if 'target' in attribs :
                depend.set('target', attribs['target'])
            else :
                if 'name' in attribs :
                    matched = self.generator.matchExdoc(attribs['name'])
                    if matched is not None :
                        depend.set('target', matched + '.xml')
                    else :
                        depend.set('target', attribs['sourcePath'])
                else :
                    depend.set('target', attribs['sourcePath'])

            root.insert(-1, depend)


        self.src = root.find('./Source')
        self.parseSource()
        if len(self.src.findall('./Definition')) == 0 :
            self.internal = True

        if self.internal is False :
            os.makedirs(os.path.dirname(self.xml_file), exist_ok=True)
            tree.write(self.xml_file, xml_declaration=True, encoding='utf-8')

    def parseSource(self) :
        attribs = self.src.attrib
        srcpath = os.path.realpath(attribs['sourcePath'])
        self.text = open(srcpath).read()

        if 'name' in attribs :
            self.depends[tuple(attribs['name'].lower().split('.'))] = self.src

        for doc in self.src.iter('Documentation') :
            self.parseDocumentation(doc)

        for defn in self.src.findall('./Definition') :
            if self.checkDefinition(defn) :
                self.src.remove(defn)
            else :
                self.parseDefinition(defn)

        for imp in self.src.iter('Import') :
            self.parseImport(imp)


        maindefn = self.src.find("./Definition")
        if maindefn is not None and maindefn.find('Documentation') is not None:
            docstring = deepcopy(maindefn.find('./Documentation'))
            self.src.append(docstring)
        else :
            self.src.append(E('Documentation', E('content', ' ')))

    def parseDefinition(self, defn) :
        attribs = defn.attrib
        if 'start' in attribs and 'body' in attribs :
            sign = self.generateSignature(attribs)
            defn.insert(-1, sign)

        if 'fullname' in attribs :
            fullname = attribs['fullname']
            best_depend = self.matchPath(fullname)
            if best_depend is not None and best_depend != self.src :
                attribs['target'] = best_depend.attrib['target']
        elif 'name' in attribs :
            attribs['fullname'] = 'ecldoc-' + attribs['name']

        for childdefn in defn.findall('./Definition') :
            if attribs['inherittype'] == 'inherited' or self.checkDefinition(childdefn):
                defn.remove(childdefn)
            else :
                self.parseDefinition(childdefn)

        parents = defn.find('./Parents')
        if parents is not None:
            for parent in parents.findall('./Parent') :
                self.parseParent(parent)

    def generateSignature(self, attribs) :
        sign = etree.Element('Signature')
        text = self.text
        if 'fullname' in attribs :
            best_depend = self.matchPath(attribs['fullname'])
            if best_depend is not None and best_depend != self.src :
                text = open(best_depend.attrib['sourcePath']).read()

        name = attribs['name']

        sign.text = text[int(attribs['start']):int(attribs['body'])]
        sign.text = re.sub(r'^export', '', sign.text, flags=re.I)
        sign.text = re.sub(r'^shared', '', sign.text, flags=re.I)
        sign.text = re.sub(r':=$', '', sign.text, flags=re.I)
        sign.text = re.sub(r';$', '', sign.text, flags=re.I)
        sign.text = sign.text.strip()

        sign.text = re.sub(r'\s+', ' ', sign.text)

        name_len = len(name)
        pos = breaksign(name, sign.text)
        ret, param = '', ''
        indent_len = 0
        if pos != -1 :
            ret = sign.text[:pos]
            param = sign.text[pos+name_len:]
            indent_len = pos+name_len
        else :
            sign.text = name

        sign.attrib['name'] = name
        sign.attrib['ret'] = ret.strip()
        sign.attrib['param'] = param.strip()
        sign.attrib['hlen'] = str(indent_len)
        return sign

    def parseDocumentation(self, doc) :
        content = doc.find('./content')
        elements = parseDocstring(content.text)
        doc.remove(content)
        for tag in elements :
            for desc in elements[tag] :
                doc.append(desc)

    def parseImport(self, imp) :
        attribs = imp.attrib
        if 'ref' in attribs :
            refpath = attribs['ref']
            attribs['target'] = self.matchReference(refpath)

    def parseParent(self, parent) :
        attribs = parent.attrib
        if 'ref' in attribs :
            refpath = attribs['ref']
            attribs['target'] = self.matchReference(refpath)


    def matchReference(self, refpath) :
        target = ''
        best_depend = self.matchPath(refpath)
        if best_depend is not None:
            target = best_depend.attrib['target']
        else :
            matched = self.generator.matchExdoc(refpath)
            if matched is not None :
                target = matched + '.xml'
            else :
                refpath = refpath.split('.')
                refpath.append('pkg.toc.xml')
                target = os.path.join(self.xml_root, *refpath)
                target = os.path.relpath(target, self.xml_dir)
        return target

    def matchPath(self, path) :
        path = tuple(path.lower().split('.'))
        current_prefix = ()
        for depend_path in self.depends :
            prefix = os.path.commonprefix([path, depend_path])
            if len(prefix) > len(current_prefix) :
                current_prefix = prefix

        if len(current_prefix) > 0 and current_prefix in self.depends:
            return self.depends[current_prefix]

        return None

    def checkDefinition(self, defn) :
        test_1 = 'exported' not in defn.attrib
        test_2 = self.options['nodoc'] and (defn.find('Documentation') is None)
        test_3 = (self.options['nointernal'] and
                (defn.find('Documentation') is not None) and
                (defn.find('Documentation').find('internal') is not None))
        return test_1 or test_2 or test_3


def check_if_modified(fpin, fpout) :
    return os.path.exists(fpout) and os.path.getmtime(fpout) > os.path.getmtime(fpin)

def parseBundle(generator, ecl_file) :
    input_file = os.path.join(generator.input_root, ecl_file)
    dirpath = os.path.dirname(input_file)

    dirpath_xml_orig = os.path.dirname(os.path.join(generator.xml_orig_root, ecl_file))
    dirpath_xml = os.path.dirname(os.path.join(generator.xml_root, ecl_file))

    bundle_orig_path = os.path.join(dirpath_xml_orig, 'bundle.orig.out')
    bundle_xml_path = os.path.join(dirpath_xml, 'bundle.xml')

    os.makedirs(dirpath_xml_orig, exist_ok=True)
    p = subprocess.call(['~/ecl-bundle info ' + dirpath + ' > ' + bundle_orig_path], shell=True)
    print("Output Code : ", p, "Bundle File : ", dirpath)

    data = open(bundle_orig_path).read().split('\n')
    data = [x.split(':', 1) for x in data]
    data = [(x[0].strip(), x[1].strip()) for x in data if len(x) == 2]
    root = etree.Element("Bundle")
    for k in data :
        node = etree.Element(k[0])
        node.text = k[1]
        root.append(node)

    os.makedirs(os.path.dirname(bundle_xml_path), exist_ok=True)
    etree.ElementTree(root).write(bundle_xml_path, pretty_print=True, xml_declaration=True, encoding='utf-8')




class GenXML(object) :
    def __init__(self, input_root, output_root, ecl_files, options) :
        self.input_root = input_root
        self.output_root = output_root
        self.ecl_files = ecl_files
        self.xml_orig_root = os.path.join(output_root, 'xmlOriginal')
        os.makedirs(self.xml_orig_root, exist_ok=True)

        self.xml_root = os.path.join(output_root, 'xml')
        os.makedirs(self.xml_root, exist_ok=True)

        self.ecl_file_tree = genPathTree(ecl_files)
        self.options = options

    def gen(self, key, node, xml_root, content_root) :
        if type(node[key]) != dict:
            if key == 'bundle.ecl' :
                parseBundle(self, node[key])
                return
            ecl_file = node[key]
            parser = ParseXML(self, ecl_file)
            # if check_if_modified(parser.input_file, parser.xml_file) :
            #   continue
            parser.parse()
            if parser.internal :
                del node[key]
            else :
                file = etree.Element('file')
                file.attrib['name'] = key + '.xml'
                file.text = node[key]
                xml_root.append(file)
        else :
            child = node[key]
            folder = etree.Element('folder')
            xml_root.append(folder)
            folder.attrib['name'] = key

            keys = list(child.keys())
            for chkey in keys :
                child_root = os.path.join(content_root, chkey)
                self.gen(chkey, child, folder, child_root)

            os.makedirs(content_root, exist_ok=True)
            toc_file = os.path.join(content_root, 'pkg.toc.xml')
            etree.ElementTree(folder).write(toc_file, pretty_print=True, xml_declaration=True, encoding='utf-8')
            self.genJSON(child, content_root)


    def genXML(self) :
        self.processExternalDoc()
        root = etree.Element('Root')
        self.gen('root', self.ecl_file_tree, root, self.xml_root)


    def genJSON(self, tree, output_path='', dump=True) :
        json_output = {}
        new_tree = deepcopy(tree)
        self.dictlower(new_tree)
        json_output['tree'] = new_tree
        json_output['output_root'] = self.output_root
        json_output['input_root'] = self.input_root
        if dump :
            json.dump(json_output, open(os.path.join(output_path, 'tree.json'), 'w'), sort_keys=True, indent=4)

        return json_output

    def processExternalDoc(self) :
        self.exdocs = []
        currdoc = self.genJSON(self.ecl_file_tree['root'], dump=False)
        self.exdocs.append(currdoc)
        for path in self.options['exdoc_paths'] :
            json_file = os.path.join(path, 'tree.json')
            assert os.path.isfile(json_file), "Exdoc file not exists : " + json_file
            external_doc = json.load(open(json_file))
            self.exdocs.append(external_doc)

    def matchExdoc(self, fullname, source='') :
        fullname = tuple(fullname.lower().split('.'))
        matched = None
        for exdoc in self.exdocs :
            val = self.checkInTree(fullname, exdoc['tree'], '')
            if val is not None:
                if source == '' or source.startswith(exdoc['input_root']):
                    matched = os.path.join(exdoc['output_root'], '$$_ECLDOC-FORM_$$', val)
                    break
        return matched


    def checkInTree(self, fullname, tree, child_root) :
        if type(tree) == dict :
            if len(fullname) == 0 : return os.path.join(child_root, 'pkg.toc')
            if fullname[0] in tree : return self.checkInTree(fullname[1:],
                                                            tree[fullname[0]]['tree'],
                                                            os.path.join(child_root, tree[fullname[0]]['key']))
            return None

        return tree

    def dictlower(self, tree) :
        keys = list(tree.keys())
        for key in keys :
            if type(tree[key]) == dict :
                self.dictlower(tree[key])
            node = tree[key]
            del tree[key]
            tree[re.sub(r'\.ecl$', '', key.lower())] = { 'key' : key, 'tree' : node }