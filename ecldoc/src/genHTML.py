import os
import re
import shutil
import subprocess
from Constants import TEMPLATE_DIR

from lxml import etree
from Utils import genPathTree, getRoot, write_to_file
from Utils import joinpath, relpath, dirname

import jinja2
from Utils import breaksign

html_jinja_env = jinja2.Environment(
    loader = jinja2.FileSystemLoader(os.path.abspath('/'))
)

def construct_type(ele) :
    if ele is None : return ''
    if type(ele) == list : return ''

    typestring = ''
    attribs = ele.attrib
    typename = attribs['type']
    if typename == 'record' :
        if 'unnamed' in attribs :
            typestring += '{ '
            fields = []
            for field in ele.findall('Field') :
                fields.append(construct_type(field.find('./Type')) + " " + field.attrib['name'])
            typestring += ' , '.join(fields) + ' }'
        else :
            typestring += attribs['origfn'] if 'origfn' in attribs else attribs['name']
    else :
        typestring += typename.upper()
        if 'origfn' in attribs :
            typestring += ' ( ' + attribs['origfn'] + ' )'
        elif 'name' in attribs :
            typestring += ' ( ' + attribs['name'] + ' )'

    if typename == 'function' :
        typestring += ' [ '
        params = []
        for p in ele.find('Params').findall('Type') :
            params.append(construct_type(p))
        typestring += ' , '.join(params) + ' ]'

    if ele.find('./Type') is not None :
        typestring += ' ( ' + construct_type(ele.find('./Type')) + ' )'

    return typestring

def construct_params(params) :
    if params is None : return ''
    params = params.findall('./Param')
    plist = []
    for p in params :
        type_ = construct_type(p.find('./Type'))
        name = p.attrib['name']
        plist.append((type_, name))

    return plist


html_jinja_env.filters['construct_type'] = construct_type
html_jinja_env.filters['construct_params'] = construct_params

class ParseHTML(object) :
    def __init__(self, generator, ecl_file) :
        self.output_root = generator.output_root
        self.xml_file = joinpath(generator.xml_root, (ecl_file + '.xml'))
        self.html_file = joinpath(generator.html_root, (ecl_file + '.html'))
        self.template = generator.content_template
        self.parent = getRoot(generator.ecl_file_tree, ecl_file)
        self.options = generator.options

        os.makedirs(dirname(self.html_file), exist_ok=True)

    def parse(self) :
        tree = etree.parse(self.xml_file)
        root = tree.getroot()
        src = root.find('./Source')
        self.src = src
        self.doc = src.find('./Documentation')

        for child in root.iter() :
            attribs = child.attrib
            if 'target' in attribs :
                attribs['target'] = re.sub(r'\$\$_ECLDOC-FORM_\$\$', 'html', attribs['target'])
                attribs['target'] = re.sub(r'\.xml$', '.html', attribs['target'])

            if 'fullname' in attribs :
                attribs['origfn'] = attribs['fullname']
                attribs['fullname'] = re.sub(r'\.', '-', attribs['fullname'])


        files = []
        keys = sorted(self.parent.keys(), key=str.lower)
        for key in keys :
            if type(self.parent[key]) != dict :
                file = {'name': key,
                        'target': key + '.html',
                        'type': 'file'}
                files.append(file)
            else :
                file = {'name': key,
                        'target': joinpath(key, 'pkg.toc.html'),
                        'type': 'dir'}
                files.append(file)

        files = sorted(files, key=lambda x : x['type'])

        parent = 'pkg.toc.html'
        output_relpath = relpath(self.output_root, dirname(self.html_file))
        render = self.template.render(src=src,
                                    files=files,
                                    parent=parent,
                                    output_root=output_relpath)
        write_to_file(self.html_file, render)

    def docstring(self) :
        text = ''
        if self.doc is not None :
            content = self.doc.find('./firstline')
            if content is not None :
                text = content.text
        return text

class GenHTML(object) :
    def __init__(self, input_root, output_root, ecl_file_tree, options) :
        self.input_root = input_root
        self.output_root = output_root
        self.html_root = joinpath(output_root, 'html')
        self.xml_root = joinpath(output_root, 'xml')

        self.template_dir = joinpath(TEMPLATE_DIR, 'html')
        self.content_template = html_jinja_env.get_template(joinpath(self.template_dir, 'content.tpl.html'))
        self.toc_template = html_jinja_env.get_template(joinpath(self.template_dir, 'toc.tpl.html'))
        self.ecl_file_tree = ecl_file_tree
        self.options = options

    def gen(self, key, node, content_root) :
        if type(node[key]) != dict:
            if key == 'bundle.ecl' :
                return None
            parser = ParseHTML(self, node[key])
            parser.parse()
            file = {'name' : key,
                    'target' : key + '.html',
                    'type' : 'file',
                    'doc' : parser.docstring() }
            return file
        else :
            child = node[key]
            file = {'name' : key,
                    'target': joinpath(key, 'pkg.toc.html'),
                    'type': 'dir',
                    'doc' : '' }

            bundle = None
            if 'bundle.ecl' in child :
                bundle_xml_path = joinpath(self.xml_root, dirname(child['bundle.ecl']), 'bundle.xml')
                bundle = etree.parse(bundle_xml_path).getroot()
                license = bundle.find('License')
                license.text = '<a href="' + license.text + '">' + license.text + '</a>'
                file['type'] = 'bundle'

            childfiles = []
            keys = sorted(child.keys(), key=str.lower)
            for chkey in keys :
                child_root = joinpath(content_root, chkey)
                child_dict = self.gen(chkey, child, child_root)
                if child_dict is not None : childfiles.append(child_dict)

            childfiles = sorted(childfiles, key=lambda x : x['type'])

            root_relpath = relpath(self.output_root, content_root)
            parent_relpath = ''
            if content_root != self.html_root :
                parent_relpath = relpath(dirname(content_root), content_root)

            render = self.toc_template.render(name=key,
                                                files=childfiles,
                                                parent=joinpath(parent_relpath, 'pkg.toc.html'),
                                                output_root=root_relpath,
                                                bundle=bundle)
            os.makedirs(content_root, exist_ok=True)
            render_path = joinpath(content_root, 'pkg.toc.html')
            write_to_file(render_path, render)

            return file



    def run(self) :
        self.gen('root', self.ecl_file_tree, self.html_root)

        if os.path.exists(joinpath(self.output_root, 'css')) :
            shutil.rmtree(joinpath(self.output_root, 'css'))
        shutil.copytree(joinpath(self.template_dir, 'css'), joinpath(self.output_root, 'css'))