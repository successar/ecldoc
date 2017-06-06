import os
import subprocess
from lxml import etree

def genHTML(input_root, output_root, ecl_files) :
	xml_orig_root = os.path.join(output_root, 'xmlOriginal')
	os.makedirs(xml_orig_root, exist_ok=True)

	xml_root = os.path.join(output_root, 'xml')
	os.makedirs(xml_root, exist_ok=True)

	for ecl_file in ecl_files :
		fpout = os.path.join(xml_orig_root, ecl_file + '.xml')
		os.makedirs(os.path.dirname(fpout), exist_ok=True)
		os.chdir(input_root)
		fpin = os.path.join(input_root, ecl_file)
		p = subprocess.call(['~/eclcc -M -o ' + fpout + ' ' + fpin], shell=True)
		print("File : ", fpin, "Output Code : ", p)
		parseXML(input_root, output_root, ecl_file)


def parseXML(input_root, output_root, ecl_file) :
	fpout = os.path.join(output_root, 'xmlOriginal', ecl_file + '.xml')
	tree = etree.parse(fpout)
	root = tree.getroot()
	for src in root.iter('Source') :
		attribs = src.attrib
		print(attribs)
		srcpath = os.path.realpath(attribs['sourcePath'])
		if os.path.exists(srcpath) and srcpath.startswith(input_root):
			relpath = os.path.relpath(srcpath, input_root)
			tgtpath = os.path.join(output_root, 'xml', relpath + '.xml')
			tgtpath = os.path.realpath(tgtpath)
			attribs['sourcePath'] = tgtpath
			if relpath == ecl_file :
				continue
			else :
				root.remove(src)
		else :
			root.remove(src)

		depend = etree.Element('Depends', sourcePath=attribs['sourcePath'])
		if 'name' in attribs :
			depend.set('name', attribs['name'])

		for imp in src.iter('Import') :
			depend.insert(-1, imp)

		root.insert(-1, depend)

	fpout = os.path.join(output_root, 'xml', ecl_file + '.xml')
	tree.write(fpout)


