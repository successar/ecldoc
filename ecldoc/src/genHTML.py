import os
import re
import subprocess
from jinja2 import Template
from lxml import etree

class ParseHTML(object) :
	def __init__(self, input_root, output_root, ecl_file, temp) :
		self.input_root = input_root
		self.output_root = output_root
		self.ecl_file = ecl_file
		self.xml_root = os.path.join(output_root, 'xml')
		self.html_root = os.path.join(output_root, 'html')
		self.xml_file = os.path.join(self.xml_root, (self.ecl_file + '.xml').lower())
		self.html_file = os.path.join(self.html_root, (self.ecl_file + '.html').lower())
		# xslt_file = etree.parse('/media/sarthak/Data/ecldoc/ecldoc/src/htmlstyle.xsl')
		# self.xslt = etree.XSLT(xslt_file)
		self.temp = temp

	def parse(self) :
		tree = etree.parse(self.xml_file)
		root = tree.getroot()
		src = root.find('./Source')
		for child in root.iter() :
			attribs = child.attrib
			if 'target' in attribs :
				target = attribs['target']
				target = re.sub(r'\.xml$', '.html', target)
				attribs['target'] = target

		render = self.temp.render(src=src)
		fp = open(self.html_file, 'w')
		fp.write(render)
		fp.close()
		#html_tree = self.xslt(tree)
		#html_tree.write(self.html_file)


def genHTML(input_root, output_root, ecl_files) :
	html_root = os.path.join(output_root, 'html')
	os.makedirs(html_root, exist_ok=True)
	t = Template(open('/media/sarthak/Data/ecldoc/ecldoc/src/template.html').read())

	for ecl_file in ecl_files :
		html_file = os.path.join(html_root, (ecl_file + '.html').lower())
		os.makedirs(os.path.dirname(html_file), exist_ok=True)
		ParseHTML(input_root, output_root, ecl_file, t).parse()
