import os
import re
import shutil
import subprocess

from jinja2 import Template
from lxml import etree
from Utils import genPathTree, getRoot

import textwrap
from parseDoc import convertToLatex
from Utils import escape_tex

import jinja2
import os
from jinja2 import Template

latex_jinja_env = jinja2.Environment(
	block_start_string = '\BLOCK{',
	block_end_string = '}',
	variable_start_string = '\VAR{',
	variable_end_string = '}',
	comment_start_string = '\#{',
	comment_end_string = '}',
	line_statement_prefix = '%%',
	line_comment_prefix = '%#',
	trim_blocks = True,
	autoescape = False,
	loader = jinja2.FileSystemLoader(os.path.abspath('/'))
)
latex_jinja_env.filters['escape_tex'] = escape_tex

class ParseTEX(object) :
	def __init__(self, generator, ecl_file) :
		self.xml_file = os.path.join(generator.xml_root, ecl_file + '.xml')
		self.tex_file = os.path.join(generator.tex_root, ecl_file + '.tex')
		self.template = generator.content_template
		self.options = generator.options
		self.dirname = os.path.dirname(ecl_file)
		if self.dirname == '' :
			self.dirname = 'root'

		os.makedirs(os.path.dirname(self.tex_file), exist_ok=True)

	def parse(self) :
		root = etree.parse(self.xml_file).getroot()
		src = root.find('./Source')
		self.src = src
		self.doc = src.find('./Documentation')
		self.parseSource()

		for child in root.iter() :
			attribs = child.attrib
			if 'target' in attribs :
				attribs['target'] = re.sub(r'\.xml$', '.tex', attribs['target'])

		render = self.template.render(src=src, render_dict=self.render_dict)
		fp = open(self.tex_file, 'w')
		fp.write(render)
		fp.close()

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
			defn_dict = self.parseDefinition(defn)
			defn_dict['up'] = 'toc:' + self.dirname
			self.render_dict.append(defn_dict)

	def parseDefinition(self, defn) :
		defn_type = defn.find('./Type').text
		sign = defn.find('./Signature')

		doc = self.parseDocs(defn.find('./Documentation'))
		if defn.attrib['inherit_type'] != 'local' :
			doc['tags'].append(('True', defn.attrib['inherit_type'].upper()))

		parents = defn.find('./Parents')
		target = defn.attrib['target'] if 'target' in defn.attrib else None

		defn_dict = {'sign' : sign, 'doc' : doc, 'defns' : [],
					'Parents' : parents, 'target' : target, 'tag' : defn }

		for childdefn in defn.findall('./Definition') :
			child_dict = self.parseDefinition(childdefn)
			child_dict['up'] = defn.attrib['fullname']
			defn_dict['defns'].append(child_dict)

		return defn_dict

	def parseDocs(self, doc) :
		doc_dict = { 'tags' : [] }
		if doc is not None:
			doc_dict['content'] = convertToLatex(doc.find('./content').text).split('\n')

			for param in doc.findall('./param') :
				param = param.find('./name').text + ' ||| ' + param.find('./desc').text
				doc_dict['tags'].append((param, 'Parameter'))

			for param in doc.findall('./field') :
				param = param.find('./name').text + ' ||| ' + param.find('./desc').text
				doc_dict['tags'].append((param, 'Field'))

			for param in doc.findall('./return') :
				doc_dict['tags'].append((param.text, 'Return'))

			for param in doc.findall('./see') :
				doc_dict['tags'].append((param.text, 'See'))

		return doc_dict



class GenTEX(object) :
	def __init__(self, input_root, output_root, ecl_files, options) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_files = ecl_files
		self.tex_root = os.path.join(output_root, 'tex')
		self.xml_root = os.path.join(output_root, 'xml')
		os.makedirs(self.tex_root, exist_ok=True)
		self.content_template = latex_jinja_env.get_template('/media/sarthak/Data/ecldoc/ecldoc/src/content.tex.tpl')
		self.toc_template = latex_jinja_env.get_template('/media/sarthak/Data/ecldoc/ecldoc/src/toc.tex.tpl')
		self.index_tex = '/media/sarthak/Data/ecldoc/ecldoc/src/tex/index.tex'
		self.ecl_file_tree = genPathTree(ecl_files)
		self.options = options

	def gen(self, node, content_root) :
		files = []
		for key in node :
			if type(node[key]) != dict:
				if key == 'bundle.ecl' :
					continue
				parser = ParseTEX(self, node[key])
				parser.parse()
				file = { 'name' : key, 'type' : 'file', 'doc' : parser.docstring() }
				target = os.path.join(content_root, key + '.tex')
				file['target'] = os.path.relpath(target, self.output_root)
				file['label'] = parser.src.attrib['name']
				files.append(file)
			else :
				child = node[key]
				file = { 'name' : key, 'type': 'dir', 'doc' : '' }

				bundle = None
				if 'bundle.ecl' in child :
					bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
					bundle = etree.parse(bundle_xml_path).getroot()
					file['type'] = 'bundle'

				child_root = os.path.join(content_root, key)
				tex_path = os.path.relpath(child_root, self.tex_root)

				childfiles = self.gen(child, child_root)
				childfiles = sorted(childfiles, key=lambda x : x['type'], reverse=True)

				render = self.toc_template.render(name=key,	files=childfiles, bundle=bundle, label=tex_path)
				render_path = os.path.join(child_root, 'pkg.toc.tex')
				fp = open(render_path, 'w')
				fp.write(render)
				fp.close()

				target = os.path.relpath(render_path, self.output_root)
				file['target'] = target
				file['label'] = tex_path

				files.append(file)

		return files



	def genTEX(self) :
		child = self.ecl_file_tree['root']
		bundle = None
		if 'bundle.ecl' in child :
			bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
			bundle = etree.parse(bundle_xml_path).getroot()

		childfiles = self.gen(child, self.tex_root)
		childfiles = sorted(childfiles, key=lambda x : x['type'], reverse=True)

		render = self.toc_template.render(name='Root', files=childfiles, bundle=bundle, label='root')
		fp = open(os.path.join(self.tex_root, 'pkg.toc.tex'), 'w')
		fp.write(render)
		fp.close()

		shutil.copy2(self.index_tex, self.output_root)
		subprocess.run(['pdflatex index.tex'], cwd=self.output_root, shell=True)




