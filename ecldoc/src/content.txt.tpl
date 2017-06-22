{%- macro desc(def) -%}
{{ '\n' + def.find('./Type').text.upper() + ' : ' + def.find('./Signature').attrib['sign'] + ' ' }}{%- if def.attrib['inherit_type'] != 'local' -%} | {{ def.attrib['inherit_type'].upper() }}
{%- endif -%}
{{ '\n' }}{{ '-' * (def.find('./Type').text.upper() + ' : ' + def.find('./Signature').attrib['sign'])|length }}{{ '\n' }}
{%- if def.find('./Documentation') -%}
{{ '\n' }}{{ def.find('./Documentation').find('./content').text }}{{ '\n' }}
{%- for tag in def.find('./Documentation').findall('./param') -%}
{{ '\n' }}Parameter : <{{ tag.find('./name').text }}> {{ tag.find('./desc').text }}{{ '\n' }}
{%- endfor -%}
{%- for tag in def.find('./Documentation').findall('./return') -%}
{{ '\n' }}Return : {{ tag.text }}{{ '\n' }}
{%- endfor -%}
{%- for tag in def.find('./Documentation').findall('./field') -%}
{{ '\n' }}Field : <{{ tag.find('./name').text }}> {{ tag.find('./desc').text }}{{ '\n' }}
{%- endfor -%}
{%- for tag in def.find('./Documentation').findall('./see') -%}
{{ '\n' }}See : {{ tag.text }}{{ '\n' }}
{%- endfor -%}
{%- endif -%}
{%- if def.find('./Parents') -%}
{%- for parent in def.find('./Parents').findall('./Parent') -%}
{%- if 'ref' in parent.attrib -%}
{{ '\n' }}Parent : {{ parent.attrib['ref'] }} <{{ parent.attrib['target'] }}>{{ '\n' }}
{%- endif -%}
{%- endfor -%}
{%- endif -%}
{%- if 'target' in def.attrib -%}
{{ '\n' }}Link : <{{ def.attrib['target'] }}>{{ '\n' }}
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
{%- for def in src.findall('./Definition') recursive -%}
{{ desc(def)|indent(loop.depth0*4, true) }}
{{ loop(def.findall('./Definition')) }}
{%- endfor -%}