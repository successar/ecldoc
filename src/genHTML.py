import os, re, shutil

from lxml import etree
from Utils import getRoot, write_to_file
from Utils import joinpath, relpath, dirname

##################################################################

from Constants import TEMPLATE_DIR
HTML_TEMPLATE_DIR = joinpath(TEMPLATE_DIR, 'html')

##################################################################

import jinja2
html_jinja_env = jinja2.Environment(
    loader = jinja2.FileSystemLoader(os.path.abspath('/'))
)

#################################################################

from parseDoc import getTags
from Taglets import taglets
from tagHTML import tag_renders

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
        src = root.find('Source')
        self.src = src
        self.doc = src.find('Documentation')

        for child in root.iter() :
            attribs = child.attrib
            if 'target' in attribs :
                attribs['target'] = re.sub(r'\$\$_ECLDOC-FORM_\$\$', 'html', attribs['target'])
                attribs['target'] = re.sub(r'\.xml$', '.html', attribs['target'])

            if 'fullname' in attribs :
                attribs['origfn'] = attribs['fullname']
                attribs['fullname'] = re.sub(r'\.', '-', attribs['fullname'])

        self.parseSource()

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
                                      output_root=output_relpath,
                                      render_dict=self.render_dict)
        write_to_file(self.html_file, render)

    def docstring(self) :
        text = ''
        if self.doc is not None :
            content = self.doc.find('firstline')
            if content is not None :
                text = content.text
        return text

    def parseSource(self) :
        self.render_dict = []
        for defn in self.src.findall('Definition') :
            self.parseDefinition(defn, self.render_dict)

    def parseDefinition(self, defn, render_dict) :
        doc = self.parseDocs(defn)
        defn_dict = { 'tag' : defn, 'doc' : doc, 'defns' : [] }

        for childdefn in defn.findall('Definition') :
            self.parseDefinition(childdefn, defn_dict['defns'])

        render_dict.append(defn_dict)

    def parseDocs(self, defn) :
        renders = {}
        tags = getTags(defn.find('Documentation'))
        always = ['param', 'field', 'return', 'parent', 'content', 'firstline']
        common_tags = list(set(tags.keys()) | set(always))
        for tag in common_tags :
            if tag not in taglets or tag not in tag_renders :
                if 'generaltag' in tag_renders :
                    render = tag_renders['generaltag'](
                                taglets['generaltag'](doc=tags[tag], defn=defn, tagname=tag))
                else :
                    render = tags[tag]
                renders[tag] = render
                continue
            render = tag_renders[tag](taglets[tag](doc=tags[tag], defn=defn, tagname=tag))
            renders[tag] = render

        return renders


class GenHTML(object) :
    def __init__(self, input_root, output_root, ecl_file_tree, options) :
        self.input_root = input_root
        self.output_root = output_root
        self.html_root = joinpath(output_root, 'html')
        self.xml_root = joinpath(output_root, 'xml')

        self.template_dir = HTML_TEMPLATE_DIR
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
        print("\nGenerating HTML Documentation ... ")
        self.gen('root', self.ecl_file_tree, self.html_root)

        if os.path.exists(joinpath(self.output_root, 'css')) :
            shutil.rmtree(joinpath(self.output_root, 'css'))
        shutil.copytree(joinpath(self.template_dir, 'css'), joinpath(self.output_root, 'css'))