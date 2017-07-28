from parseDoc import construct_type, convertToMarkdown
from genTXT import CPL, _break

def parseTag(text, heading) :
	heading = heading
	text_break = _break(text, CPL * 0.5)
	spaces = [heading] + ([' ' * len(heading)] * (len(text_break)-1))
	text_list = [(a + b) for a, b in zip(spaces, text_break)]
	return text_list

def render_param(tag_param) :
	render = {'param' : []}
	lines = render['param']
	for t in tag_param.tuples['tuples'] :
		lines.append(parseTag(construct_type(t[2]) + ' --- ' + t[1], 'Parameter : ' + t[0] + ' '))
	return render

def render_field(tag_field) :
	render = {'field' : []}
	lines = render['field']
	for t in tag_field.tuples['tuples'] :
		lines.append(parseTag(construct_type(t[2]) + ' --- ' + t[1], 'Field : ' + t[0] + ' '))
	return render

def render_return(tag_return) :
	render = {'return' : []}
	lines = render['return']
	if len(tag_return.docstrings) == 0 and tag_return.return_type is None : return render
	lines.append(parseTag(construct_type(tag_return.return_type) + ' ' + tag_return.return_desc, 'Return : '))
	return render

def render_see(tag_see) :
	render = {'see' : []}
	lines = render['see']
	for t in tag_see.tuples['tuples'] :
		lines.append(parseTag(t[0], 'See : '))
	return render

def render_parent(tag_parent) :
	render = {'parent' : []}
	lines = render['parent']
	for t in tag_parent.tuples['tuples'] :
		lines.append(parseTag(t[0] + ' <' + t[1] + '>', 'Parent : '))
	return render

def render_content(tag_content) :
	render = {'content' : []}
	mktext = convertToMarkdown(tag_content.text).split('\n')
	lines = []
	for t in mktext :
		lines += _break(t, CPL*0.75)
	render['content'] = lines
	return render

def render_firstline(tag_firstline) :
	render = {'firstline' : []}
	render['firstline'].append([tag_firstline.text])
	return render

tag_renders = { 'param' : render_param,
				'field' : render_field,
				'return' : render_return,
				'see' : render_see,
				'parent' : render_parent,
				'content' : render_content,
				'firstline' : render_firstline
			  }
