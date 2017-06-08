import os
import re
import subprocess
from lxml import etree

class ParseXML(object) :
	def __init__(self, input_root, output_root, ecl_file) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_file = ecl_file
		self.xml_root = os.path.join(output_root, 'xml')
		self.xml_orig_file = os.path.join(output_root, 'xmlOriginal', (ecl_file + '.xml').lower())
		self.xml_file = os.path.join(self.xml_root, (self.ecl_file + '.xml').lower())

	def parse(self) :
		tree = etree.parse(self.xml_orig_file)
		root = tree.getroot()

		self.depends = {}

		for src in root.iter('Source') :
			attribs = src.attrib
			srcpath = os.path.realpath(attribs['sourcePath'])
			attribs['sourcePath'] = srcpath

			if os.path.exists(srcpath) and srcpath.startswith(self.input_root):
				relpath = os.path.relpath(srcpath, self.input_root)
				tgtpath = os.path.join(self.xml_root, (relpath + '.xml').lower())
				tgtpath = os.path.realpath(tgtpath)
				attribs['targetPath'] = tgtpath
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

			if 'targetPath' in attribs :
				depend.set('targetPath', attribs['targetPath'])

			root.insert(-1, depend)

		self.src = root.find('./Source')
		self.parseSource()

		os.makedirs(os.path.dirname(self.xml_file), exist_ok=True)
		tree.write(self.xml_file)

	def parseSource(self) :
		attribs = self.src.attrib
		srcpath = os.path.realpath(attribs['sourcePath'])
		self.text = open(srcpath).read()

		if 'name' in attribs :
			self.depends[tuple(attribs['name'].lower().split('.'))] = self.src

		for defn in self.src.findall('./Definition') :
			self.parseDefinition(defn)

		for doc in self.src.iter('Documentation') :
			self.parseDocumentation(doc)

		for imp in self.src.iter('Import') :
			self.parseImport(imp)

	def parseDefinition(self, defn) :
		attribs = defn.attrib
		if 'start' in attribs and 'body' in attribs :
			sign = self.generateSignature(attribs)
			defn.insert(-1, sign)

		for childdefn in defn.findall('./Definition') :
			if attribs['inherit_type'] != 'inherited' :
				self.parseDefinition(childdefn)
			else :
				defn.remove(childdefn)

		parents = defn.find('./Parents')
		if parents is not None:
			for parent in parents.findall('./Parent') :
				self.parseParent(parent)

	def generateSignature(self, attribs) :
		sign = etree.Element('Signature')
		if attribs['inherit_type'] == 'inherited' :
			if 'source' in attribs and os.path.exists(attribs['source']):
				text = open(attribs['source']).read()
				srcpath = os.path.realpath(attribs['source'])
				if srcpath.startswith(self.input_root) :
					relpath = os.path.relpath(srcpath, self.input_root)
					tgtpath = os.path.join(self.xml_root, (relpath + '.xml').lower())
					tgtpath = os.path.realpath(tgtpath)
					attribs['target'] = tgtpath
		else :
			text = self.text

		sign.text = text[int(attribs['start']):int(attribs['body'])]
		sign.text = sign.text.replace("EXPORT", "").replace("SHARED", "").replace(";", "").replace(":=", "").strip()
		return sign

	def parseDocumentation(self, doc) :
		for child in doc.iter() :
			child.text = re.sub(r'\s+', ' ', child.text)

	def parseImport(self, imp) :
		attribs = imp.attrib
		if 'ref' in attribs :
			refpath = attribs['ref']
			best_depend = self.parsePath(refpath)
			if best_depend is not None :
				if 'targetPath' in best_depend.attrib :
					attribs['target'] = best_depend.attrib['targetPath']
				else :
					attribs['target'] = best_depend.attrib['sourcePath']
			else :
				attribs['target'] = os.path.join(*([self.xml_root] + refpath.lower().split('.')))

	def parseParent(self, parent) :
		attribs = parent.attrib
		if 'ref' in attribs :
			refpath = attribs['ref']
			best_depend = self.parsePath(refpath)
			if best_depend is not None:
				if 'targetPath' in best_depend.attrib :
					attribs['target'] = best_depend.attrib['targetPath']
				else :
					attribs['target'] = best_depend.attrib['sourcePath']


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

def genXML(input_root, output_root, ecl_files) :
	xml_orig_root = os.path.join(output_root, 'xmlOriginal')
	os.makedirs(xml_orig_root, exist_ok=True)

	xml_root = os.path.join(output_root, 'xml')
	os.makedirs(xml_root, exist_ok=True)

	print(ecl_files)
	for ecl_file in ecl_files :
		input_file = os.path.join(input_root, ecl_file)
		xml_orig_file = os.path.join(xml_orig_root, (ecl_file + '.xml').lower())
		# if check_if_modified(fpin, fpout) :
		# 	continue
		os.makedirs(os.path.dirname(xml_orig_file), exist_ok=True)
		os.chdir(input_root)
		p = subprocess.call(['~/eclcc -M -o ' + xml_orig_file + ' ' + input_file], shell=True)
		print("File : ", input_file, "Output Code : ", p)
		ParseXML(input_root, output_root, ecl_file).parse()






