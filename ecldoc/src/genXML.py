import os
import re
import json
import subprocess
from copy import deepcopy
from lxml import etree
from lxml.builder import E
from Utils import genPathTree

class ParseXML(object) :
	def __init__(self, input_root, output_root, ecl_file) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_file = ecl_file
		self.xml_root = os.path.join(output_root, 'xml')
		self.xml_orig_file = os.path.join(output_root, 'xmlOriginal', (ecl_file + '.xml').lower())
		self.xml_file = os.path.join(self.xml_root, (self.ecl_file + '.xml').lower())
		self.xml_dir = os.path.dirname(self.xml_file)

	def parse(self) :
		tree = etree.parse(self.xml_orig_file)
		root = tree.getroot()

		self.depends = {}

		for src in root.iter('Source') :
			attribs = src.attrib
			srcpath = os.path.realpath(attribs['sourcePath'])

			if os.path.exists(srcpath) and srcpath.startswith(self.input_root):
				attribs['sourcePath'] = srcpath
				relpath = os.path.relpath(srcpath, self.input_root)
				tgtpath = os.path.join(self.xml_root, (relpath + '.xml').lower())
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
			fullname = attribs['fullname'].lower()
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

		sign.attrib['sign'] = sign.text
		sign.attrib['name'] = name
		return sign

	def parseDocumentation(self, doc) :
		for child in doc.iter() :
			child.text = re.sub(r'\s+', ' ', child.text)

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
			attribs['ref'] = refpath.lower()
			best_depend = self.parsePath(refpath)
			if best_depend is not None :
				attribs['target'] = best_depend.attrib['target']
			else :
				refpath = refpath.lower().split('.')
				refpath.append('pkg.toc.xml')
				attribs['target'] = os.path.join(self.xml_root, *refpath)
				attribs['target'] = os.path.relpath(attribs['target'], self.xml_dir)

	def parseParent(self, parent) :
		attribs = parent.attrib
		if 'ref' in attribs :
			refpath = attribs['ref']
			attribs['ref'] = refpath.lower()
			best_depend = self.parsePath(refpath)
			if best_depend is not None:
				attribs['target'] = best_depend.attrib['target']
			else :
				refpath = refpath.lower().split('.')
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

def genXML(input_root, output_root, ecl_files, only_bundle) :
	xml_orig_root = os.path.join(output_root, 'xmlOriginal')
	os.makedirs(xml_orig_root, exist_ok=True)

	xml_root = os.path.join(output_root, 'xml')
	os.makedirs(xml_root, exist_ok=True)

	path_tree = genPathTree(ecl_files, ".xml")
	json_output = os.path.join(output_root, "index_xml.json")
	with open(json_output, "w") as index_out :
		json.dump(path_tree, index_out, indent=4)

	for ecl_file in ecl_files :
		input_file = os.path.join(input_root, ecl_file)
		xml_orig_file = os.path.join(xml_orig_root, (ecl_file + '.xml').lower())
		os.makedirs(os.path.dirname(xml_orig_file), exist_ok=True)
		xml_file = os.path.join(xml_root, (ecl_file + '.xml').lower())
		os.chdir(input_root)
		# if check_if_modified(input_file, xml_file) :
		# 	continue
		split = os.path.split(input_file)
		if split[1].lower() == 'bundle.ecl' :
			dirpath = os.path.join(split[0], '')
			bundle_orig_path = os.path.join(os.path.split(xml_orig_file)[0], 'bundle.orig.out')
			bundle_xml_path = os.path.join(os.path.split(xml_file)[0], 'bundle.xml')
			p = subprocess.call(['~/ecl-bundle info ' + dirpath + ' > ' + bundle_orig_path], shell=True)
			print("Output Code : ", p, "Bundle File : ", dirpath)
			parseBundle(bundle_orig_path, bundle_xml_path)
		else :
			p = subprocess.call(['~/eclcc -M -o ' + xml_orig_file + ' ' + input_file], shell=True)
			print("File : ", input_file, "Output Code : ", p)
			print(input_file)
			parser = ParseXML(input_root, output_root, ecl_file)
			parser.parse()

	parent = path_tree['root']
	root = etree.Element('folder')
	root.attrib['name'] = 'root'
	genTOC(parent, root, xml_root)
	toc_file = os.path.join(xml_root, 'pkg.toc.xml')
	fp = open(toc_file, 'wb')
	fp.write(etree.tostring(root))
	fp.close()


def genTOC(parent, root, output_root) :
	for key in parent :
		if type(parent[key]) != dict :
			file = etree.Element('file')
			file.attrib['name'] = key + '.xml'
			file.text = parent[key]
			root.append(file)
		else :
			folder = etree.Element('folder')
			root.append(folder)
			folder.attrib['name'] = key

			genTOC(parent[key], folder, os.path.join(output_root, key))

			toc_file = os.path.join(output_root, key , 'pkg.toc.xml')
			fp = open(toc_file, 'wb')
			fp.write(etree.tostring(folder))
			fp.close()


def parseBundle(bundle_orig_path, bundle_xml_path) :
	data = open(bundle_orig_path).read().split('\n')
	data = [x.split(':', 1) for x in data]
	data = {x[0].strip() : x[1].strip() for x in data if len(x) == 2}
	root = etree.Element("Bundle")
	for k in data :
		node = etree.Element(k)
		node.text = data[k]
		root.append(node)

	os.makedirs(os.path.dirname(bundle_xml_path), exist_ok=True)
	etree.ElementTree(root).write(bundle_xml_path, pretty_print=True, xml_declaration=True, encoding='utf-8')







