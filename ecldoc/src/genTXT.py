import os
import re
import subprocess

from jinja2 import Template
from lxml import etree
from Utils import genPathTree, getRoot

import textwrap
from parseDoc import convertToMarkdown

CPL = 100

def _break(text, CPL_E) :
	CPL_E = int(CPL_E)
	break_text = textwrap.wrap(text, CPL_E)
	if len(break_text) == 0 :
		break_text = ['']
	return break_text

class ParseTXT(object) :
	def __init__(self, generator, ecl_file) :
		self.input_root = generator.input_root
		self.output_root = generator.output_root
		self.ecl_file = ecl_file
		self.xml_root = generator.xml_root
		self.txt_root = generator.txt_root
		self.xml_file = os.path.join(self.xml_root, (self.ecl_file + '.xml'))
		self.txt_file = os.path.join(self.txt_root, (self.ecl_file + '.txt'))
		os.makedirs(os.path.dirname(self.txt_file), exist_ok=True)
		self.template = generator.content_template
		parent = getRoot(generator.ecl_file_tree, ecl_file)
		self.parent = parent
		self.options = generator.options

	def parse(self) :
		tree = etree.parse(self.xml_file)
		root = tree.getroot()
		src = root.find('./Source')
		self.src = src
		self.doc = src.find('./Documentation')
		self.parseSource()

		for child in root.iter() :
			attribs = child.attrib
			if 'target' in attribs :
				target = attribs['target']
				target = re.sub(r'\.xml$', '.txt', target)
				attribs['target'] = target

			if 'fullname' in attribs :
				fullname = attribs['fullname']
				fullname = re.sub(r'\.', '-', fullname)
				attribs['fullname'] = fullname

		files = []
		for key in self.parent :
			if type(self.parent[key]) != dict :
				file = {}
				file['name'] = key
				file['target'] = key + '.txt'
				file['type'] = 'file'
				files.append(file)
			else :
				file = {}
				file['name'] = key
				file['target'] = os.path.join(key, 'pkg.toc.txt')
				file['type'] = 'dir'
				files.append(file)

		parent = 'pkg.toc.txt'
		relpath = os.path.relpath(self.output_root, os.path.dirname(self.txt_file))
		render = self.template.render(src=src,
									files=files,
									parent=parent,
									output_root=relpath,
									render_dict=self.render_dict)
		fp = open(self.txt_file, 'w')
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
		src = self.src
		self.render_dict = []
		for defn in src.findall('./Definition') :
			self.parseDefinition(defn, self.render_dict)

	def parseDefinition(self, defn, render_dict) :
		defn_type = defn.find('./Type').text
		sign = defn.find('./Signature').text
		if defn.attrib['inherit_type'] != 'local' :
			sign += ' ||| ' + defn.attrib['inherit_type'].upper()

		heading = defn_type.upper() + ' : '
		spaces = len(heading)
		EFF_CPL = CPL - spaces
		sign_break = _break(sign, EFF_CPL)
		type_break = [heading] + ([' '*spaces] * (len(sign_break) - 1))
		headers = [(a + b) for a,b in zip(type_break, sign_break)]

		doc = self.parseDocs(defn.find('./Documentation'))
		parents = defn.find('./Parents')
		target = defn.attrib['target'] if 'target' in defn.attrib else None
		defn_dict = { 'headers' : headers, 'doc' : doc, 'defns' : [], 'Parents' : parents, 'target' : target}
		for childdefn in defn.findall('./Definition') :
			self.parseDefinition(childdefn, defn_dict['defns'])

		render_dict.append(defn_dict)

	def parseDocs(self, doc) :
		doc_dict = {}
		if doc is not None:
			doc_dict['content'] = []
			content = convertToMarkdown(doc.find('./content').text).split('\n')
			for x in content :
				doc_dict['content'] += _break(x, CPL * 0.75)

			doc_dict['tags'] = []
			for param in doc.findall('./param') :
				param = param.find('./name').text + ' ||| ' + param.find('./desc').text
				doc_dict['tags'].append(self.parseTag(param, 'Parameter'))

			for param in doc.findall('./field') :
				param = param.find('./name').text + ' ||| ' + param.find('./desc').text
				doc_dict['tags'].append(self.parseTag(param, 'Field'))

			for param in doc.findall('./return') :
				doc_dict['tags'].append(self.parseTag(param.text, 'Return'))

			for param in doc.findall('./see') :
				doc_dict['tags'].append(self.parseTag(param.text, 'See'))

		return doc_dict


	def parseTag(self, text, heading) :
		heading = heading + ' : '
		text_break = _break(text, CPL * 0.5)
		spaces = [heading] + ([' ' * len(heading)] * (len(text_break)-1))
		text_list = [(a + b) for a, b in zip(spaces, text_break)]
		return text_list



class GenTXT(object) :
	def __init__(self, input_root, output_root, ecl_files, options) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_files = ecl_files
		self.txt_root = os.path.join(output_root, 'txt')
		self.xml_root = os.path.join(output_root, 'xml')
		self.content_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/content.txt.tpl').read())
		self.toc_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/toc.txt.tpl').read())
		self.ecl_file_tree = genPathTree(ecl_files)
		self.options = options

	def gen(self, node, content_root) :
		files = []
		for key in node :
			if type(node[key]) != dict:
				if key == 'bundle.ecl' :
					continue
				ecl_file = node[key]
				parser = ParseTXT(self, ecl_file)
				parser.parse()
				file = { 'name' : key, 'target' : key + '.txt', 'type' : 'file', 'doc' : parser.docstring() }
				files.append(file)
			else :
				child = node[key]
				file = { 'name' : key,'target': os.path.join(key, 'pkg.toc.txt'), 'type': 'dir', 'doc' : '' }

				bundle = None
				if 'bundle.ecl' in child :
					bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
					tree = etree.parse(bundle_xml_path)
					bundle = tree.getroot()
					file['type'] = 'bundle'

				child_root = os.path.join(content_root, key)
				root_relpath = os.path.relpath(self.output_root, child_root)
				parent_relpath = os.path.relpath(content_root, child_root)
				os.makedirs(child_root, exist_ok=True)

				childfiles = self.gen(child, child_root)
				childfiles = sorted(childfiles, key=lambda x : x['type'])

				render = self.toc_template.render(name=key,
													files=childfiles,
													parent=os.path.join(parent_relpath, 'pkg.toc.txt'),
													output_root=root_relpath,
													bundle=bundle)
				render_path = os.path.join(child_root, 'pkg.toc.txt')
				fp = open(render_path, 'w')
				fp.write(render)
				fp.close()

				files.append(file)

		return files



	def genTXT(self) :
		files = self.gen(self.ecl_file_tree['root'], self.txt_root)
		files = sorted(files, key=lambda x : x['type'])
		render = self.toc_template.render(name='root',
										files=files,
										parent='pkg.toc.txt',
										output_root=os.path.relpath(self.output_root, self.txt_root))
		fp = open(os.path.join(self.txt_root, 'pkg.toc.txt'), 'w')
		fp.write(render)
		fp.close()

