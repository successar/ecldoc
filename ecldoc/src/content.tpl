{% macro simpletag(name, xpath, def, double=false) %}
	{% if def.find('./Documentation') %}
	{% if def.find('./Documentation').findall(xpath) %}
	<div class="row">
		<div class="col-md-1 doc-type">{{ name }}</div>
		<div class="col-md-11" style="padding-left: 0px;">
			<table class="table">
				{% for tag in def.find('./Documentation').findall(xpath) %}
				<tr>
					{% if double %}
					<td width="20%"><b>{{ tag.find('./name').text }}</b> </td>
					<td>{{ tag.find('./desc').text }}</td>
					{% else %}
					<td>{{ tag.text }}</td>
					{% endif %}
				</tr>
				{% endfor %}
			</table>
		</div>
	</div>
	{% endif %}
	{% endif %}
{% endmacro %}

<!DOCTYPE html>
<html lang="en">

<head>

	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width, shrink-to-fit=no, initial-scale=1">
	<title>{{ src.attrib['name'] }}</title>
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" />
	<link href="https://maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css" rel="stylesheet" />
	<link href="{{ output_root }}/css/simple-sidebar.css" rel="stylesheet">

</head>

<body>
	<nav class="navbar topbar">
		<div class="container-fluid">
			<div class="navbar-header">
				<a href="#menu-toggle" id="menu-toggle" class="navbar-brand glyphicon glyphicon-menu-hamburger ham"></a>
			</div>
			<div class="navbar-header" style="margin-left: 20px;">
				<span class="navbar-brand">{{ src.attrib['name'] }}</span>
			</div>
			<div class="navbar-collapse collapse">
				<ul class="nav navbar-nav">
					<li><a href="#ecldoc-section-import" class="topbar">Imports</a></li>
					<li><a href="#ecldoc-section-desc" class="topbar">Contents</a></li>
				</ul>
			</div>
		</div>
	</nav>
	<div id="wrapper">

		<!-- Sidebar -->
		<div id="sidebar-wrapper">
			<ul class="sidebar-nav">
				<li class="sidebar-brand">
					<a href="{{ parent }}">
						Up
					</a>
				</li>
				{% for d in files %}
				<li>
					<a href="{{ d.target }}">{{ d.name }}</a>
				</li>
				{% endfor %}
			</ul>
		</div>

		<div id="page-content-wrapper">
			<div class="container-fluid">
				<section id="ecldoc-section-import">
					<h3 class="page-header">IMPORTS</h3>
					<ul class="pagination">
						{% for imp in src.findall('./Import') -%}
						<li>
							{% if 'ref' in imp.attrib -%}
							<a href="{{ imp.attrib['target'] }}">
								{{ imp.attrib['ref'] }}
							</a>
							{% endif -%}
						</li>
						{% endfor -%}
					</ul>
				</section>
				<section id="ecldoc-section-desc">
					<h3 class="page-header">CONTENTS</h3>
					<div class="panel-group desc-panel-group">
						{% for def in src.findall('./Definition') recursive -%}
						<div class="panel panel-info desc-panel" id="d{{ def.attrib['fullname'] }}">
							<a href=".desc-{{ def.attrib['fullname'] }}" data-toggle="collapse">
								<div class="panel-heading clearfix desc-panel-heading">
									<div class="panel-title desc-type">
											{{ def.find('./Type').text.upper() }}
									</div>
									<div class="panel-title desc-sign">
										{{ def.attrib['name'] }}
									</div>
									<div class="pull-right desc-btns">
										{% if def.attrib['inherit_type'] != 'local' %}
										<span class="inherit_type"> {{ def.attrib['inherit_type'].upper() }}</span>
										{% endif %}
									</div>
								</div>
							</a>

							<table class="table sign-list">
								<tr>
									<td class="ret">{{ def.find('./Signature').attrib['ret'] }}</td>
									<td class="name">{{ def.find('./Signature').attrib['name'] }}</td>
									<td class="param">{{ def.find('./Signature').attrib['param'] }}</td>
								</tr>
								{% if def.find('./Documentation') is not none -%}
								<tr style="background: #f2f7ff;">
									<td colspan="3">
										{{ def.find('./Documentation').find('./firstline').text }}
									</td>
								</tr>
								{% endif %}
							</table>
							{% if loop.depth0 == 0 %}
							<div class="panel-collapse collapse in desc-{{ def.attrib['fullname'] }}">
							{% else %}
							<div class="panel-collapse collapse desc-{{ def.attrib['fullname'] }}">
							{% endif %}
								<div class="panel-body desc-panel-body">
									{% if def.find('./Documentation') is not none -%}
									<div class="row">
										<div class="col-md-12" style="padding-bottom: 10px;">
											{{ def.find('./Documentation').find('./content').text }}
										</div>
									</div>
									{% endif %}
									{{ simpletag('Parameters', './param', def, double=true) }}
									{{ simpletag('Fields', './field', def, double=true) }}
									{{ simpletag('Returns', './return', def) }}
									{{ simpletag('Also See', './see', def) }}

									{% if def.find('./Parents') -%}
									<div class="row">
										<div class="col-md-1 doc-type">Parent</div>
										<div class="col-md-11" style="padding-left: 0px;">
											<ul class="pagination" style="margin-top: 0px;">
												{% for parent in def.find('./Parents').findall('./Parent') -%}
												<li>
													{% if 'ref' in parent.attrib -%}
													<a href="{{ parent.attrib['target'] }}">
														{{ parent.attrib['ref'] }}
													</a>
													{% endif -%}
												</li>
												{% endfor -%}
											</ul>
										</div>
									</div>
									{% endif -%}

									{% if 'target' in def.attrib -%}
									<div class="row">
										<div class="col-md-12">
											<a href="{{ def.attrib['target'] }}" class="btn btn-success" style="background: #00563B;">External Link</a>
										</div>
									</div>
									{% endif -%}
								</div>
								<div class="panel-footer desc-panel-footer">
									<div class="panel-group desc-panel-group">
									{{ loop(def.findall('./Definition')) }}
									</div>
								</div>
							</div>
						</div>
						{% endfor -%}
					</div>
				</section>
			</div>
		</div>
	</div>

	<script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>

	<!-- Menu Toggle Script -->
	<script>
		$("#menu-toggle").click(function(e) {
			e.preventDefault();
			$("#wrapper").toggleClass("toggled");
		});
	</script>
</body>
</html>