import os
import re
import subprocess

from lxml import etree
from Utils import genPathTree, getRoot, write_to_file

from jinja2 import Template
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
		self.xml_file = os.path.join(generator.xml_root, ecl_file + '.xml')
		self.txt_file = os.path.join(generator.txt_root, ecl_file + '.txt')
		self.template = generator.content_template
		self.options = generator.options

		os.makedirs(os.path.dirname(self.txt_file), exist_ok=True)

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
		doc = self.parseDocs(defn.find('./Documentation'))
		parents = defn.find('./Parents')
		defn_dict = { 'headers' : headers, 'doc' : doc, 'defns' : [], 'Parents' : parents }

		for childdefn in defn.findall('./Definition') :
			self.parseDefinition(childdefn, defn_dict['defns'])

		render_dict.append(defn_dict)

	def parseSign(self, defn) :
		defn_type = defn.find('./Type').text
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
	def __init__(self, input_root, output_root, ecl_file_tree, options) :
		self.input_root = input_root
		self.output_root = output_root
		self.txt_root = os.path.join(output_root, 'txt')
		self.xml_root = os.path.join(output_root, 'xml')
		self.content_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/content.tpl.txt').read())
		self.toc_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/toc.tpl.txt').read())
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
			file = { 'name' : key,'target': os.path.join(key, 'pkg.toc.txt'), 'type': 'dir', 'doc' : '' }

			bundle = None
			if 'bundle.ecl' in child :
				bundle_xml_path = os.path.join(self.xml_root, os.path.dirname(child['bundle.ecl']), 'bundle.xml')
				bundle = etree.parse(bundle_xml_path).getroot()
				file['type'] = 'bundle'

			childfiles = []
			keys = sorted(list(child.keys()), key=str.lower)
			for chkey in keys :
				child_root = os.path.join(content_root, chkey)
				child_dict = self.gen(chkey, child, child_root)
				if child_dict is not None : childfiles.append(child_dict)

			childfiles = sorted(childfiles, key=lambda x : x['type'])
			os.makedirs(content_root, exist_ok=True)
			render = self.toc_template.render(name=key,	files=childfiles, bundle=bundle)
			render_path = os.path.join(content_root, 'pkg.toc.txt')
			write_to_file(render_path, render)

			return file


	def run(self) :
		self.gen('root', self.ecl_file_tree, self.txt_root)
