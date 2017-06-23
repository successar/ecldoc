{%- macro desc(def) -%}
{%- for h in def['headers'] -%}
{{ '\n' + h }}
{%- endfor -%}
{{ '\n' }}{{ '-' * 130 }}{{ '\n' }}
{%- if 'content' in def['doc'] -%}
{{ '\n' }}
{%- for line in def['doc']['content'] -%}
{{ line }}{{ '\n' }}
{%- endfor -%}
{%- endif -%}
{%- if 'tags' in def['doc'] -%}
{%- for tag in def['doc']['tags'] -%}
{%- for line in tag -%}
{{ '\n' }}{{ line }}
{%- endfor -%}
{{ '\n' }}
{%- endfor -%}
{%- endif -%}
{%- if def['Parents'] -%}
{%- for parent in def['Parents'].findall('./Parent') -%}
{%- if 'ref' in parent.attrib -%}
{{ '\n' }}Parent : {{ parent.attrib['ref'] }} <{{ parent.attrib['target'] }}>{{ '\n' }}
{%- endif -%}
{%- endfor -%}
{%- endif -%}
{%- if 'target' in def -%}
{{ '\n' }}Link : <{{ def['target'] }}>{{ '\n' }}
{%- endif -%}
{%- endmacro -%}
IMPORTS
=======
{{ '\n' }}
{%- for imp in src.findall('./Import') -%}
{%- if 'ref' in imp.attrib -%}
{{ '\n' + imp.attrib['ref'] }} <{{ imp.attrib['target'] }}>
{%- endif -%}
{%- endfor -%}
{{ '\n' }}
DESCRIPTIONS
============
{{ '\n' }}
{%- for def in render_dict recursive -%}
{{ desc(def)|indent(loop.depth0*4, true) }}
{{ loop(def['defns']) }}
{%- endfor -%}