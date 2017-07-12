import os
import re
import shutil
import subprocess

from lxml import etree
from Utils import genPathTree, getRoot, write_to_file

from jinja2 import Template
from Utils import breaksign

class ParseHTML(object) :
    def __init__(self, generator, ecl_file) :
        self.output_root = generator.output_root
        self.xml_file = os.path.join(generator.xml_root, (ecl_file + '.xml'))
        self.html_file = os.path.join(generator.html_root, (ecl_file + '.html'))
        self.template = generator.content_template
        self.parent = getRoot(generator.ecl_file_tree, ecl_file)
        self.options = generator.options

        os.makedirs(os.path.dirname(self.html_file), exist_ok=True)

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
                        'target': os.path.join(key, 'pkg.toc.html'),
                        'type': 'dir'}
                files.append(file)

        files = sorted(files, key=lambda x : x['type'])

        parent = 'pkg.toc.html'
        relpath = os.path.relpath(self.output_root, os.path.dirname(self.html_file))
        render = self.template.render(src=src,
                                    files=files,
                                    parent=parent,
                                    output_root=relpath)
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
        self.html_root = os.path.join(output_root, 'html')
        self.xml_root = os.path.join(output_root, 'xml')
        self.content_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/content.tpl.html').read())
        self.toc_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/toc.tpl.html').read())
        self.ecl_file_tree = ecl_file_tree
        self.options = options

    def gen(self, node, content_root) :
        files = []
        keys = sorted(node.keys(), key=str.lower)
        for key in keys :
            if type(node[key]) != dict:
                parser = ParseHTML(self, node[key])
                parser.parse()
                file = {'name' : key,
                        'target' : key + '.html',
                        'type' : 'file',
                        'doc' : parser.docstring() }
                files.append(file)
            else :
                child = node[key]
                file = {'name' : key,
                        'target': os.path.join(key, 'pkg.toc.html'),
                        'type': 'dir',
                        'doc' : '' }

                bundle = None
                if 'bundle.ecl' in child :
                    bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
                    bundle = etree.parse(bundle_xml_path).getroot()
                    license = bundle.find('License')
                    license.text = '<a href="' + license.text + '">' + license.text + '</a>'
                    file['type'] = 'bundle'
                    del child['bundle.ecl']

                child_root = os.path.join(content_root, key)
                os.makedirs(child_root, exist_ok=True)

                childfiles = self.gen(child, child_root)
                childfiles = sorted(childfiles, key=lambda x : x['type'])

                root_relpath = os.path.relpath(self.output_root, child_root)
                parent_relpath = os.path.relpath(content_root, child_root)

                render = self.toc_template.render(name=key,
                                                    files=childfiles,
                                                    parent=os.path.join(parent_relpath, 'pkg.toc.html'),
                                                    output_root=root_relpath,
                                                    bundle=bundle)
                render_path = os.path.join(child_root, 'pkg.toc.html')
                write_to_file(render_path, render)
                files.append(file)

        return files



    def genHTML(self) :
        child = self.ecl_file_tree['root']

        bundle = None
        if 'bundle.ecl' in child :
            bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
            bundle = etree.parse(bundle_xml_path).getroot()
            license = bundle.find('License')
            license.text = '<a href="' + license.text + '">' + license.text + '</a>'
            del child['bundle.ecl']

        files = self.gen(child, self.html_root)
        files = sorted(files, key=lambda x : x['type'])

        render = self.toc_template.render(name='root',
                                            files=files,
                                            parent='pkg.toc.html',
                                            output_root=os.path.relpath(self.output_root, self.html_root),
                                            bundle=bundle)
        write_to_file(os.path.join(self.html_root, 'pkg.toc.html'), render)

        if os.path.exists(os.path.join(self.output_root, 'css')) :
            shutil.rmtree(os.path.join(self.output_root, 'css'))
        shutil.copytree('/media/sarthak/Data/ecldoc/ecldoc/src/css', os.path.join(self.output_root, 'css'))
        if os.path.exists(os.path.join(self.output_root, 'js')) :
            shutil.rmtree(os.path.join(self.output_root, 'js'))
        shutil.copytree('/media/sarthak/Data/ecldoc/ecldoc/src/js', os.path.join(self.output_root, 'js'))
