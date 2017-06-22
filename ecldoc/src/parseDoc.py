import re
from lxml import etree
from lxml.builder import E
import lxml.html as H
from collections import defaultdict

def parseDocstring(docstring) :
	docstring = re.sub(r'\n\s*\*', '\n', docstring)
	docstring = re.sub(r'\r', ' ', docstring)
	docstring = docstring.strip().split('\n')

	docdict = defaultdict(list)
	current_tag = 'content'
	current_text = ''
	for line in docstring :
		is_tag = re.search(r'^\s*@', line)
		if is_tag :
			if current_tag == 'content' :
				docdict['firstline'] = [findFirstLine(current_text)]
			docdict[current_tag].append(current_text.strip())
			line = re.split(r'\s', line.lstrip(), maxsplit=1)
			tag = line[0][1:]
			text = line[1]
			current_tag = tag
			current_text = text + '\n'
		else :
			current_text += line + '\n'


	if current_tag == 'content' :
		docdict['firstline'] = [findFirstLine(current_text)]
	docdict[current_tag].append(current_text.strip())

	for tag in docdict :
		for i, desc in enumerate(docdict[tag]) :
			desc = desc.strip()
			root = H.fragment_fromstring(desc, create_parent='div')
			removeWS(root)
			content = etree.Element(tag)
			content.text = etree.tostring(root)
			content.text = re.sub(r'^<div>', '', content.text)
			content.text = re.sub(r'</div>$', '', content.text)
			docdict[tag][i] = content


	return docdict

def removeWS(element) :
	if element.tag == 'pre' :
		lines = element.text.split('\n')
		element.text = lines[0]

		for line in lines[1:] :
			br = etree.Element('br')
			br.tail = line
			element.append(br)
		return

	if element.text is not None :
		element.text = re.sub(r'\s+', ' ', element.text)
	for e in element.iterchildren() :
		if e.tail :
			e.tail = re.sub(r'\s+', ' ', e.tail)

		removeWS(e)

def findFirstLine(current_text) :
	split_1 = re.split(r'\.\s|\.$', current_text.strip(), maxsplit=1)
	if len(split_1) == 2 :
		return split_1[0]

	split_2 = re.split(r'\n', current_text.strip(), maxsplit=1)
	return split_2[0]
