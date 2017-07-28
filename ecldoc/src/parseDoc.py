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
            root = H.fragment_fromstring(desc, create_parent='div')
            removeWS(root)
            content = etree.Element(tag)
            content.text = etree.tostring(root)
            content.text = re.sub(r'^<div>', '', content.text)
            content.text = re.sub(r'</div>$', '', content.text)
            docdict[tag][i] = content

    return docdict

def getTags(doc) :
    tag_dict = defaultdict(list)
    if doc is None : return tag_dict
    for child in doc.getchildren() :
        tag_dict[child.tag].append(child.text)

    return tag_dict

def removeWS(element) :
    '''
    Format Whitespace in HTML elements in docstring
    coming from parsed XML Output of ECL File
    '''
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
    '''
    Find First line in docstring content section to be used as caption
    in TOC and Tree
    '''
    split_1 = re.split(r'\.\s|\.$', current_text.strip(), maxsplit=1)
    if len(split_1) == 2 :
        return split_1[0].strip()

    split_2 = re.split(r'\n', current_text.strip(), maxsplit=1)
    return split_2[0].strip()

##########################################################

def construct_type(ele) :
    if ele is None : return ''
    if type(ele) == list : return ''

    typestring = ''
    attribs = ele.attrib
    typename = attribs['type']
    if typename == 'record' :
        if 'unnamed' in attribs :
            typestring += '{ '
            fields = []
            for field in ele.findall('Field') :
                fields.append(construct_type(field.find('./Type')) + " " + field.attrib['name'])
            typestring += ' , '.join(fields) + ' }'
        else :
            typestring += attribs['origfn'] if 'origfn' in attribs else attribs['name']
    else :
        typestring += typename.upper()
        if 'origfn' in attribs :
            typestring += ' ( ' + attribs['origfn'] + ' )'
        elif 'name' in attribs :
            typestring += ' ( ' + attribs['name'] + ' )'

    if typename == 'function' :
        typestring += ' [ '
        params = []
        for p in ele.find('Params').findall('Type') :
            params.append(construct_type(p))
        typestring += ' , '.join(params) + ' ]'

    if ele.find('./Type') is not None :
        typestring += ' ( ' + construct_type(ele.find('./Type')) + ' )'

    return typestring

##########################################################

def convertToMarkdown(html_text) :
    '''
    Convert HTML String to Markdown Format
    '''
    root = H.fragment_fromstring(html_text, create_parent='div')
    text = parseHTMltoMK(root)
    return text

def parseHTMltoMK(element) :
    '''
    Convert Single HTML element to Markdown Text (recursive)
    '''
    text = ''
    if element.text :
        text += element.text
    for e in element.iterchildren() :
        text += parseHTMltoMK(e)
        if e.tail :
            text += e.tail

    if element.tag in ['p', 'pre', 'ul', 'ol', 'table'] :
        text = '\n' + text + '\n'

    if element.tag == 'br' :
        text = '\n'

    if element.tag == 'code' :
        text = '```' + text  + '```'

    if element.tag == 'li' and element.getparent().tag == 'ul':
        text = '+ ' + text + '\n'

    if element.tag == 'li' and element.getparent().tag == 'ol':
        text = '# ' + text + '\n'

    if element.tag == 'td' :
        text = text + ' | '

    if element.tag == 'tr' :
        text = '| ' + text + '\n'

    if element.tag == 'hr' :
        text = '\n************\n'

    if element.tag == 'a' :
        text = text + ' <' + a.attrib['href'] + '>'

    return text

##########################################################

from Utils import escape_tex


def convertToLatex(html_text) :
    '''
    Convert HTML String to Markdown Format
    '''
    root = H.fragment_fromstring(html_text, create_parent='div')
    text = parseHTMltoLatex(root)
    return text

def parseHTMltoLatex(element) :
    '''
    Convert Single HTML element to Markdown Text (recursive)
    '''
    text = ''
    if element.text :
        text += escape_tex(element.text)
    for e in element.iterchildren() :
        text += parseHTMltoLatex(e)
        if e.tail :
            text += escape_tex(e.tail)

    if element.tag in ['p'] :
        text = '\n\\par\n' + text + '\n\n'

    if element.tag == 'br' :
        text = '\\\\\n'

    if element.tag == 'br' and element.getparent().tag == 'pre' :
        text = '\n'

    if element.tag == 'code' :
        text = '```' + text  + '```'

    if element.tag == 'li' :
        text = '\\item ' + text + '\n'

    if element.tag == 'ul' :
        text = '\n\\begin{itemize}\n' + text + '\\end{itemize}\n\n'

    if element.tag == 'ul' :
        text = '\n\\begin{enumerate}\n' + text + '\\end{enumerate}\n\n'

    if element.tag == 'a' :
        text = '\n\\url{' + a.attrib['href'] + '}'

    if element.tag == 'pre' :
        text = '\n\\begin{verbatim}\n' + text + '\\end{verbatim}\n\n'

    return text