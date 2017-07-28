import os
import re
import subprocess
from Constants import TEMPLATE_DIR

from lxml import etree
from Utils import genPathTree, getRoot, write_to_file, indent_doc
from Utils import joinpath, relpath, dirname

from parseDoc import getTags

TXT_TEMPLATE_DIR = joinpath(TEMPLATE_DIR, 'txt')

import jinja2
import textwrap

txt_jinja_env = jinja2.Environment(
    loader = jinja2.FileSystemLoader(os.path.abspath('/'))
)
txt_jinja_env.filters['indent_doc'] = indent_doc

CPL = 100

def _break(text, CPL_E) :
    CPL_E = int(CPL_E)
    break_text = textwrap.wrap(text, CPL_E)
    if len(break_text) == 0 :
        break_text = ['']
    return break_text

from Taglets import taglets
from tagTXT import tag_renders

class ParseTXT(object) :
    def __init__(self, generator, ecl_file) :
        self.xml_file = joinpath(generator.xml_root, ecl_file + '.xml')
        self.txt_file = joinpath(generator.txt_root, ecl_file + '.txt')
        self.template = generator.content_template
        self.options = generator.options

        os.makedirs(dirname(self.txt_file), exist_ok=True)

    def parse(self) :
        root = etree.parse(self.xml_file).getroot()
        src = root.find('./Source')
        self.src = src
        self.doc = src.find('./Documentation')
        self.parseSource()

        for child in root.iter() :
            attribs = child.attrib
            if 'target' in attribs :
                attribs['target'] = re.sub(r'\$\$_ECLDOC-FORM_\$\$', 'txt', attribs['target'])
                attribs['target'] = re.sub(r'\.xml$', '.txt', attribs['target'])

        render = self.template.render(src=src, render_dict=self.render_dict)
        write_to_file(self.txt_file, render)

    def docstring(self) :
        text = ''
        if self.doc is not None :
            content = self.doc.find('./firstline')
            if content is not None :
                text = content.text
        return text

    def parseSource(self) :
        self.render_dict = []
        for defn in self.src.findall('./Definition') :
            self.parseDefinition(defn, self.render_dict)

    def parseDefinition(self, defn, render_dict) :
        headers = self.parseSign(defn)
        doc = self.parseDocs(defn)
        defn_dict = { 'headers' : headers, 'doc' : doc, 'defns' : [] }

        for childdefn in defn.findall('./Definition') :
            self.parseDefinition(childdefn, defn_dict['defns'])

        render_dict.append(defn_dict)

    def parseSign(self, defn) :
        defn_type = defn.attrib['type']
        sign = defn.find('./Signature').text
        hlen = int(defn.find('./Signature').attrib['hlen'])
        if defn.attrib['inherittype'] != 'local' :
            sign += ' ||| ' + defn.attrib['inherittype'].upper()

        heading = defn_type.upper() + ' : '
        spaces = len(heading)
        sign_break = _break(sign, CPL - spaces)
        type_break = [heading] + ([' '*(spaces + hlen)] * (len(sign_break) - 1))
        headers = [(a + b) for a,b in zip(type_break, sign_break)]
        return headers

    def parseDocs(self, defn) :
        renders = {}
        tags = getTags(defn.find('Documentation'))
        always = ['param', 'field', 'return', 'parent', 'content', 'firstline']
        common_tags = list(set(tags.keys()) | set(always))
        for tag in common_tags :
            if tag not in taglets or tag not in tag_renders :
                continue
            render = tag_renders[tag](taglets[tag](doc=tags[tag], defn=defn))
            renders[tag] = render[tag]

        return renders


class GenTXT(object) :
    def __init__(self, input_root, output_root, ecl_file_tree, options) :
        self.input_root = input_root
        self.output_root = output_root
        self.txt_root = joinpath(output_root, 'txt')
        self.xml_root = joinpath(output_root, 'xml')
        self.template_dir = joinpath(TEMPLATE_DIR, 'txt')
        self.content_template = txt_jinja_env.get_template(joinpath(self.template_dir, 'content.tpl.txt'))
        self.toc_template = txt_jinja_env.get_template(joinpath(self.template_dir, 'toc.tpl.txt'))
        self.ecl_file_tree = ecl_file_tree
        self.options = options

    def gen(self, key, node, content_root) :
        if type(node[key]) != dict:
            if key == 'bundle.ecl' :
                return None
            parser = ParseTXT(self, node[key])
            parser.parse()
            file = { 'name' : key, 'target' : key + '.txt', 'type' : 'file', 'doc' : parser.docstring() }
            return file
        else :
            child = node[key]
            file = { 'name' : key,'target': joinpath(key, 'pkg.toc.txt'), 'type': 'dir', 'doc' : '' }

            bundle = None
            if 'bundle.ecl' in child :
                bundle_xml_path = joinpath(self.xml_root, dirname(child['bundle.ecl']), 'bundle.xml')
                bundle = etree.parse(bundle_xml_path).getroot()
                file['type'] = 'bundle'

            childfiles = []
            keys = sorted(list(child.keys()), key=str.lower)
            for chkey in keys :
                child_root = joinpath(content_root, chkey)
                child_dict = self.gen(chkey, child, child_root)
                if child_dict is not None : childfiles.append(child_dict)

            childfiles = sorted(childfiles, key=lambda x : x['type'])
            os.makedirs(content_root, exist_ok=True)
            render = self.toc_template.render(name=key, files=childfiles, bundle=bundle)
            render_path = joinpath(content_root, 'pkg.toc.txt')
            write_to_file(render_path, render)

            return file


    def run(self) :
        self.gen('root', self.ecl_file_tree, self.txt_root)
