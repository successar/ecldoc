from genTEX import latex_jinja_env, TEX_TEMPLATE_DIR
from Utils import call_macro_by_name, joinpath
from parseDoc import construct_type, convertToLatex

latex_jinja_env.filters['macro'] = call_macro_by_name
tag_template = latex_jinja_env.get_template(joinpath(TEX_TEMPLATE_DIR, 'taglets.tpl.tex'))

def render_param(tag_param) :
	if len(tag_param.tuples['tuples']) == 0 : return ''
	tex_tuples = []
	for t in tag_param.tuples['tuples'] :
		tex_tuples.append((t[0], construct_type(t[2]), t[1]))

	render = tag_template.render(render_name='threetag', args=['Parameter', tex_tuples])
	return render

def render_field(tag_field) :
	if len(tag_field.tuples['tuples']) == 0 : return ''
	html_tuples = []
	for t in tag_field.tuples['tuples'] :
		html_tuples.append((t[0], construct_type(t[2]), t[1]))

	return tag_template.render(render_name='threetag', args=['Field', html_tuples])

def render_return(tag_return) :
	if len(tag_return.docstrings) == 0 and tag_return.return_type is None : return ''
	return_tuple = [(construct_type(tag_return.return_type), tag_return.return_desc)]
	return tag_template.render(render_name='twotag', args=['Return', return_tuple])

def render_see(tag_see) :
	render = tag_template.render(render_name='onetag', args=['See', tag_see.tuples['tuples']])
	return render

def render_parent(tag_parent) :
	if len(tag_parent.tuples['tuples']) == 0 : return ''
	render = tag_template.render(render_name='linktag', args=['Parent', tag_parent.tuples['tuples']])
	return render

def render_content(tag_content) :
	text_latex = convertToLatex(tag_content.text).split('\n')
	render = tag_template.render(render_name='contenttag', args=[text_latex])
	return render

def render_firstline(tag_firstline) :
	text_latex = convertToLatex(tag_firstline.text)
	return text_latex

def render_inherit(tag_inherit) :
	if tag_inherit == 'local' : return ''
	render = tag_template.render(render_name='onetag', args=[tag_inherit, [('', )]])
	return render

tag_renders = { 'param' : render_param,
				'field' : render_field,
				'return' : render_return,
				'see' : render_see,
				'parent' : render_parent,
				'content' : render_content,
				'firstline' : render_firstline,
				'inherit' : render_inherit
			  }