import os
import re
import subprocess

import jinja2
from lxml import etree
from Utils import genPathTree, getRoot
from Utils import joinpath, relpath, dirname

from parseDoc import convertToLatex
from Utils import escape_tex, write_to_file

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
		self.tex_path = generator.tex_path
		self.index_template = generator.index_template
		self.xml_file = joinpath(generator.xml_root, ecl_file + '.xml')
		self.tex_file = joinpath(generator.tex_root, ecl_file + '.tex')
		self.template = generator.content_template
		self.options = generator.options
		tex_relpath = relpath(self.tex_file, generator.tex_path)
		self.dirname = dirname(tex_relpath)
		self.index_render_path = joinpath(generator.tex_root, ecl_file + '.tmp.tex')

		os.makedirs(dirname(self.tex_file), exist_ok=True)

	def parse(self) :
		root = etree.parse(self.xml_file).getroot()
		src = root.find('./Source')
		self.src = src
		self.doc = src.find('./Documentation')
		self.parseSource()

		for child in root.iter() :
			attribs = child.attrib
			if 'target' in attribs :
				attribs['target'] = re.sub(r'\$\$_ECLDOC-FORM_\$\$', joinpath('tex', 'root'), attribs['target'])
				attribs['target'] = re.sub(r'\.xml$', '.tex', attribs['target'])

		name = src.attrib['name'].split('.')

		render = self.template.render(name=name, src=src, render_dict=self.render_dict, up=('toc:'+self.dirname))
		write_to_file(self.tex_file, render)

		# start_path = relpath(self.tex_file, self.tex_path)
		# render = self.index_template.render(root=start_path)
		# write_to_file(self.index_render_path, render)

		# subprocess.run(['pdflatex ' +
		# 				'-output-directory ' + self.dirname + ' ' +
		# 				relpath(self.index_render_path, self.tex_path)],
		# 				cwd=self.tex_path, shell=True)

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
			self.render_dict.append(defn_dict)

	def parseDefinition(self, defn) :
		defn_type = defn.find('./Type').text
		sign = defn.find('./Signature')

		doc = self.parseDocs(defn.find('./Documentation'))
		if defn.attrib['inherittype'] != 'local' :
			doc['tags'].append((('', 'True'), defn.attrib['inherittype'].upper()))

		parents = defn.find('./Parents')
		target = defn.attrib['target'] if 'target' in defn.attrib else None

		defn_dict = {'sign' : sign, 'doc' : doc, 'defns' : [],
					'Parents' : parents, 'target' : target, 'tag' : defn }

		for childdefn in defn.findall('./Definition') :
			child_dict = self.parseDefinition(childdefn)
			defn_dict['defns'].append(child_dict)

		return defn_dict

	def parseDocs(self, doc) :
		doc_dict = { 'tags' : [] }
		if doc is not None:
			doc_dict['firstline'] = convertToLatex(doc.find('./firstline').text).strip()
			doc_dict['content'] = convertToLatex(doc.find('./content').text).split('\n')

			for param in doc.findall('./param') :
				param = (param.find('./name').text , param.find('./desc').text)
				doc_dict['tags'].append((param, 'Parameter'))

			for param in doc.findall('./field') :
				param = (param.find('./name').text, param.find('./desc').text)
				doc_dict['tags'].append((param, 'Field'))

			for param in doc.findall('./return') :
				param = ('', param.text)
				doc_dict['tags'].append((param, 'Return'))

			for param in doc.findall('./see') :
				param = ('', param.text)
				doc_dict['tags'].append((param, 'See'))

		return doc_dict



class GenTEX(object) :
	def __init__(self, input_root, output_root, ecl_file_tree, options) :
		self.input_root = input_root
		self.output_root = output_root

		self.tex_path = joinpath(output_root, 'tex')
		self.tex_root = joinpath(output_root, 'tex', 'root')
		self.xml_root = joinpath(output_root, 'xml')
		os.makedirs(self.tex_root, exist_ok=True)

		self.content_template = latex_jinja_env.get_template('/media/sarthak/Data/ecldoc/ecldoc/src/content.tpl.tex')
		self.toc_template = latex_jinja_env.get_template('/media/sarthak/Data/ecldoc/ecldoc/src/toc.tpl.tex')
		self.index_template = latex_jinja_env.get_template('/media/sarthak/Data/ecldoc/ecldoc/src/tex/index.tpl.tex')

		self.ecl_file_tree = ecl_file_tree
		self.options = options

	def gen(self, key, node, content_root) :
		if type(node[key]) != dict:
			if key == 'bundle.ecl' :
				return
			parser = ParseTEX(self, node[key])
			parser.parse()
			file = { 'name' : key, 'type' : 'file', 'doc' : parser.docstring() }
			file['target'] = relpath(parser.tex_file, self.tex_path)
			file['label'] = parser.src.attrib['name']
			return file
		else :
			child = node[key]

			os.makedirs(content_root, exist_ok=True)
			render_path = joinpath(content_root, 'pkg.toc.tex')
			temptoc_render_path = joinpath(content_root, 'pkg.tmp.tex')
			index_render_path = joinpath(content_root, 'index.tex')

			tex_relpath = relpath(content_root, self.tex_path)
			target_relpath = relpath(render_path, self.tex_path)

			file = { 'name' : key, 'type': 'dir', 'doc' : '' , 'target' : target_relpath, 'label' : tex_relpath }

			bundle = None
			if 'bundle.ecl' in child :
				bundle_xml_path = joinpath(self.xml_root, dirname(child['bundle.ecl']), 'bundle.xml')
				bundle = etree.parse(bundle_xml_path).getroot()
				file['type'] = 'bundle'

			childfiles = []
			keys = sorted(child.keys(), key=str.lower)
			for chkey in keys :
				child_root = joinpath(content_root, chkey)
				child_dict = self.gen(chkey, child, child_root)
				if child_dict is not None : childfiles.append(child_dict)

			childfiles = sorted(childfiles, key=lambda x : x['type'], reverse=True)

			render = self.toc_template.render(name=key,	files=childfiles, bundle=bundle,
											label=tex_relpath, up=dirname(tex_relpath))
			write_to_file(render_path, render)

			render = self.toc_template.render(name=key,
											files=list(filter(lambda x : x['type'] == 'file', childfiles)),
											bundle=bundle, label=tex_relpath, up="")
			write_to_file(temptoc_render_path, render)

			start_path = relpath(temptoc_render_path, self.tex_path)
			render = self.index_template.render(root=start_path)
			write_to_file(index_render_path, render)

			subprocess.run(['pdflatex ' +
							'-output-directory ' + relpath(content_root, self.tex_path) + ' ' +
							relpath(index_render_path, self.tex_path)],
							cwd=self.tex_path, shell=True)

			return file


	def run(self) :
		self.gen('root', self.ecl_file_tree, self.tex_root)

		render_path = joinpath(self.tex_root, 'pkg.toc.tex')
		start_path = relpath(render_path, self.tex_path)
		render = self.index_template.render(root=start_path)
		write_to_file(joinpath(self.tex_path, 'index.tex'), render)

		subprocess.run(['pdflatex index.tex'], cwd=self.tex_path, shell=True)




