<html>
<head>
	<title></title>
	<meta content="">
	<style></style>
</head>
<body>
	<h2>Imports	</h2>
	<ul>
		{% for imp in src.findall('./Import') %}
		<li>
			{% if 'ref' in imp.attrib %}
			<a href="{{ imp.attrib['target'] }}">
				{{ imp.attrib['ref'] }}
			</a>
			{% endif %}
		</li>
		{% endfor %}
	</ul>
	<h2>Tree</h2>
	<ul>
		{% for def in src.findall('./Definition') recursive %}
		<li>
			{{ def.find('./Type').text.upper() }} : {{ def.find('./Signature').text }}
			<ul>
				{{ loop(def.findall('./Definition')) }}
			</ul>
		</li>
		{% endfor %}
	</ul>
	<hr/>
	<h2>Descriptions</h2>
	{% for def in src.findall('./Definition') recursive %}
	<p>	{{ def.find('./Type').text.upper() }} : {{ def.find('./Signature').text }}
		{% if 'target' in def.attrib %}
		<br/>
		<a href="{{ def.attrib['target'] }}">External Link </a>
		{% endif %}
		<br/>
		{% if def.find('./Parents') %}
		<h4>Parent</h4>
		<ul>
			{% for parent in def.find('./Parents').findall('./Parent') %}
			<li>
				{% if 'ref' in parent.attrib %}
				<a href="{{ parent.attrib['target'] }}">
					{{ parent.attrib['ref'] }}
				</a>
				{% endif %}
			</li>
			{% endfor %}
		</ul>
		{% endif %}
		Inherit Type : {{ def.attrib['inherit_type'] }}
		<br/>
		{% if def.find('./Documentation') %}
		{% for tag in def.find('./Documentation').iterchildren() %}
		@{{ tag.tag }} : {{ tag.text }}
		<br/>
		{% endfor %}
		{% endif %}
	</p>
	<hr/>
	{{ loop(def.findall('./Definition')) }}
	{% endfor %}
</body>
</html>