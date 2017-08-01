from parseDoc import construct_type, convertToMarkdown
from genTXT import CPL, _break

def parseTag(text, heading) :
    heading = heading
    text_break = _break(text, CPL * 0.5)
    spaces = [heading] + ([' ' * len(heading)] * (len(text_break)-1))
    text_list = [(a + b) for a, b in zip(spaces, text_break)]
    return text_list

def render_param(tag_param) :
    lines = []
    for t in tag_param.tuples['tuples'] :
        lines.append(parseTag(construct_type(t[2]) + ' --- ' + t[1], 'Parameter : ' + t[0] + ' '))
    return lines

def render_field(tag_field) :
    lines = []
    for t in tag_field.tuples['tuples'] :
        lines.append(parseTag(construct_type(t[2]) + ' --- ' + t[1], 'Field : ' + t[0] + ' '))
    return lines

def render_return(tag_return) :
    lines = []
    if len(tag_return.docstrings) == 0 and tag_return.return_type is None : return lines
    lines.append(parseTag(construct_type(tag_return.return_type) + ' ' + tag_return.return_desc, 'Return : '))
    return lines

def render_see(tag_see) :
    lines = []
    for t in tag_see.tuples['tuples'] :
        lines.append(parseTag(t[0], 'See : '))
    return lines

def render_parent(tag_parent) :
    lines = []
    for t in tag_parent.tuples['tuples'] :
        lines.append(parseTag(t[0] + ' <' + t[1] + '>', 'Parent : '))
    return lines

def render_content(tag_content) :
    mktext = convertToMarkdown(tag_content.text).split('\n')
    lines = []
    for t in mktext :
        lines += _break(t, CPL*0.75)
    return lines

def render_firstline(tag_firstline) :
    lines = []
    lines.append([tag_firstline.text])
    return lines

def render_generaltag(tag_generaltag) :
    lines = []
    for t in tag_generaltag.tuples['tuples'] :
        lines.append(parseTag(t[0], tag_generaltag.tuples['name'] + ' : '))
    return lines

tag_renders = { 'param' : render_param,
                'field' : render_field,
                'return' : render_return,
                'see' : render_see,
                'parent' : render_parent,
                'content' : render_content,
                'firstline' : render_firstline,
                'generaltag' : render_generaltag
              }
