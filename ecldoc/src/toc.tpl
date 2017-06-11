<html>
<head>
	<title></title>
	<meta content="">
	<style></style>
</head>
<body>
	<h2>{{ name }}</h2>
	<hr/>
	<ul>
	{% for d in files %}
		<li>
			<a href="{{ d.target }}">{{ d.name }}</a>
		</li>
	{% endfor %}
	</ul>

</body>
</html>