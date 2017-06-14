import os
import re
import json
from jinja2 import Template
from lxml import etree
from Utils import genPathTree, getRoot

class ParseHTML(object) :
	def __init__(self, input_root, output_root, ecl_file, template, path_tree) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_file = ecl_file
		self.xml_root = os.path.join(output_root, 'xml')
		self.html_root = os.path.join(output_root, 'html')
		self.xml_file = os.path.join(self.xml_root, (self.ecl_file + '.xml').lower())
		self.html_file = os.path.join(self.html_root, (self.ecl_file + '.html').lower())
		self.template = template
		parent, parent_path = getRoot(path_tree, ecl_file)
		self.parent = parent
		self.parent_path = parent_path

	def parse(self) :
		tree = etree.parse(self.xml_file)
		root = tree.getroot()
		src = root.find('./Source')
		self.src = src
		for child in root.iter() :
			attribs = child.attrib
			if 'target' in attribs :
				target = attribs['target']
				target = re.sub(r'\.xml$', '.html', target)
				attribs['target'] = target

			if 'fullname' in attribs :
				fullname = attribs['fullname']
				fullname = re.sub(r'\.', '-', fullname)
				attribs['fullname'] = fullname

		parents = {}
		for file in self.parent :
			if type(self.parent[file]) != dict :
				parents[file] = file + '.html'
			else :
				parents[file] = os.path.join(file, 'pkg.toc.html')

		parent = 'pkg.toc.html'

		render = self.template.render(src=src, files=parents, parent=parent)
		fp = open(self.html_file, 'w')
		fp.write(render)
		fp.close()

def genHTML(input_root, output_root, ecl_files) :
	html_root = os.path.join(output_root, 'html')
	os.makedirs(html_root, exist_ok=True)
	content_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/content.tpl').read())
	toc_template = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/toc.tpl').read())

	path_tree = genPathTree(ecl_files, ".html")
	json_output = os.path.join(output_root, "index_html.json")
	with open(json_output, "w") as index_out :
		json.dump(path_tree, index_out, indent=4)

	for ecl_file in ecl_files :
		html_file = os.path.join(html_root, (ecl_file + '.html').lower())
		parser = ParseHTML(input_root, output_root, ecl_file, content_template, path_tree)
		parser.parse()

	files = genTOC(path_tree['root'], toc_template, html_root)
	render = toc_template.render(name='root', files=files, parent=os.path.join(html_root, 'pkg.toc.html'))
	fp = open(os.path.join(html_root, 'pkg.toc.html'), 'w')
	fp.write(render)
	fp.close()


def genTOC(parent, template, output_root) :
	files = []
	for key in parent :
		if type(parent[key]) != dict :
			file = {}
			file['name'] = key + '.html'
			file['target'] = key + '.html'
			file['type'] = 'file'
			files.append(file)
		else :
			file = {}
			file['name'] = key
			file['target'] = os.path.join(key, 'pkg.toc.html')
			file['type'] = 'dir'
			files.append(file)

			childfiles = genTOC(parent[key], template, os.path.join(output_root, key))
			render = template.render(name=key, files=childfiles, parent=os.path.join(output_root, 'pkg.toc.html'))
			fp = open(os.path.join(output_root, key, 'pkg.toc.html'), 'w')
			fp.write(render)
			fp.close()

	return files

