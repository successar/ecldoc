import os
import re
import subprocess
from copy import deepcopy
from lxml import etree
from lxml.builder import E
from Utils import genPathTree
from parseDoc import parseDocstring

class ParseXML(object) :
	def __init__(self, generator, ecl_file) :
		self.input_root = generator.input_root
		self.output_root = generator.output_root
		self.ecl_file = ecl_file
		self.xml_root = generator.xml_root
		self.xml_orig_root = generator.xml_orig_root

		self.input_file = os.path.join(self.input_root, ecl_file)
		self.xml_orig_file = os.path.join(self.xml_orig_root, (ecl_file + '.xml'))
		self.xml_file = os.path.join(self.xml_root, (ecl_file + '.xml'))
		self.xml_dir = os.path.dirname(self.xml_file)


	def parse(self) :
		os.chdir(self.input_root)
		os.makedirs(os.path.dirname(self.xml_orig_file), exist_ok=True)
		p = subprocess.call(['~/eclcc -M -o ' + self.xml_orig_file + ' ' + self.input_file], shell=True)
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
				else :
					root.remove(src)
			else :
				root.remove(src)

			depend = etree.Element('Depends', sourcePath=attribs['sourcePath'])

			if 'name' in attribs :
				depend.set('name', attribs['name'])
				self.depends[tuple(attribs['name'].lower().split('.'))] = depend

			if 'target' in attribs :
				depend.set('target', attribs['target'])
			else :
				depend.set('target', attribs['sourcePath'])

			root.insert(-1, depend)


		self.src = root.find('./Source')
		self.parseSource()

		os.makedirs(os.path.dirname(self.xml_file), exist_ok=True)
		tree.write(self.xml_file, xml_declaration=True, encoding='utf-8')

	def parseSource(self) :
		attribs = self.src.attrib
		srcpath = os.path.realpath(attribs['sourcePath'])
		self.text = open(srcpath).read()

		if 'name' in attribs :
			self.depends[tuple(attribs['name'].lower().split('.'))] = self.src

		for defn in self.src.findall('./Definition') :
			if 'exported' in defn.attrib :
				self.parseDefinition(defn)
			else :
				self.src.remove(defn)

		for doc in self.src.iter('Documentation') :
			self.parseDocumentation(doc)

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
			best_depend = self.parsePath(fullname)
			if best_depend is not None and best_depend != self.src :
				attribs['target'] = best_depend.attrib['target']
		elif 'name' in attribs :
			attribs['fullname'] = 'ecldoc-' + attribs['name']

		for childdefn in defn.findall('./Definition') :
			if attribs['inherit_type'] == 'inherited' or 'exported' not in childdefn.attrib:
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
		if 'source' in attribs :
			source = os.path.realpath(attribs['source'])
			if os.path.exists(source) :
				text = open(source).read()
		elif 'fullname' in attribs :
			best_depend = self.parsePath(attribs['fullname'])
			if best_depend is not None and best_depend != self.src :
				text = open(best_depend.attrib['sourcePath']).read()

		name = attribs['name']

		sign.text = text[int(attribs['start']):int(attribs['body'])]
		sign.text = re.sub(r'^export', '', sign.text, flags=re.I)
		sign.text = re.sub(r'^shared', '', sign.text, flags=re.I)
		sign.text = re.sub(r':=$', '', sign.text, flags=re.I)
		sign.text = re.sub(r';$', '', sign.text, flags=re.I)
		sign.text = sign.text.strip()
		split = re.split(name, sign.text, maxsplit=1, flags=re.I)
		if len(split) != 2 :
			sign.text = name

		sign.text = re.sub(r'\s+', ' ', sign.text)
		sign.attrib['sign'] = sign.text
		sign.attrib['name'] = name
		return sign

	def parseDocumentation(self, doc) :
		content = doc.find('./content')
		elements = parseDocstring(content.text)
		for tag in elements :
			for desc in elements[tag] :
				doc.append(desc)
		doc.remove(content)

		for p in (doc.findall('./param') + doc.findall('./field')):
			text = p.text.split(' ')
			name = etree.Element('name')
			name.text = text[0]
			desc = etree.Element('desc')
			desc.text = " ".join(text[1:])
			p.append(name)
			p.append(desc)
			p.text = ''

	def parseImport(self, imp) :
		attribs = imp.attrib
		if 'ref' in attribs :
			refpath = attribs['ref']
			best_depend = self.parsePath(refpath)
			if best_depend is not None :
				attribs['target'] = best_depend.attrib['target']
			else :
				refpath = refpath.split('.')
				refpath.append('pkg.toc.xml')
				attribs['target'] = os.path.join(self.xml_root, *refpath)
				attribs['target'] = os.path.relpath(attribs['target'], self.xml_dir)

	def parseParent(self, parent) :
		attribs = parent.attrib
		if 'ref' in attribs :
			refpath = attribs['ref']
			best_depend = self.parsePath(refpath)
			if best_depend is not None:
				attribs['target'] = best_depend.attrib['target']
			else :
				refpath = refpath.split('.')
				refpath.append('pkg.toc.xml')
				attribs['target'] = os.path.join(self.xml_root, *refpath)
				attribs['target'] = os.path.relpath(attribs['target'], self.xml_dir)

	def parsePath(self, path) :
		path = tuple(path.lower().split('.'))
		current_prefix = ()
		for depend_path in self.depends :
			prefix = os.path.commonprefix([path, depend_path])
			if len(prefix) > len(current_prefix) :
				current_prefix = prefix

		if len(current_prefix) > 0 and current_prefix in self.depends:
			return self.depends[current_prefix]

		return None


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

	def gen(self, node, xml_root, content_root) :
		for key in node :
			if type(node[key]) != dict:
				if key == 'bundle.ecl' :
					parseBundle(self, node[key])
					continue
				ecl_file = node[key]
				file = etree.Element('file')
				file.attrib['name'] = key + '.xml'
				file.text = node[key]
				xml_root.append(file)

				parser = ParseXML(self, ecl_file)
				# if check_if_modified(parser.input_file, parser.xml_file) :
				# 	continue
				parser.parse()

			else :
				child = node[key]
				folder = etree.Element('folder')
				xml_root.append(folder)
				folder.attrib['name'] = key

				child_root = os.path.join(content_root, key)
				os.makedirs(child_root, exist_ok=True)

				self.gen(child, folder, child_root)

				toc_file = os.path.join(child_root, 'pkg.toc.xml')
				etree.ElementTree(folder).write(toc_file, pretty_print=True, xml_declaration=True, encoding='utf-8')


	def genXML(self) :
		root = etree.Element('folder')
		root.attrib['name'] = 'root'
		self.gen(self.ecl_file_tree['root'], root, self.xml_root)
		toc_file = os.path.join(self.xml_root, 'pkg.toc.xml')
		etree.ElementTree(root).write(toc_file, pretty_print=True, xml_declaration=True, encoding='utf-8')

