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
					<li><a href="#ecldoc-section-tree" class="topbar">Tree</a></li>
					<li><a href="#ecldoc-section-desc" class="topbar">Descriptions</a></li>
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
				<section id="ecldoc-section-tree">
					<h3 class="page-header">DEFINITION TREE</h3>
					<ul class="tree">
						{% for def in src.findall('./Definition') recursive -%}
						<li id="t-{{ def.attrib['fullname'] }}">
							{% if def.findall('./Definition') %}
							<a href="#{{ def.attrib['fullname'] }}" data-toggle="collapse" class="glyphicon glyphicon-folder-open" style="margin-right: 6px;"></a>
							{% else %}
							<span class="glyphicon glyphicon-file" style="margin-right: 6px;"></span>
							{% endif %}
							<a href="#d{{ def.attrib['fullname'] }}">
								{{ def.find('./Type').text.upper() }} :
								<span class="sign-name">{{ def.find('./Signature').attrib['name'] }}</span>
							</a>
							<ul id="{{ def.attrib['fullname'] }}" class="accordian-body tree collapse">
								{{ loop(def.findall('./Definition')) }}
							</ul>
						</li>
						{% endfor -%}
					</ul>
				</section>
				<section id="ecldoc-section-desc">
					<h3 class="page-header">DESCRIPTIONS</h3>
					<div class="panel-group">
						{% for def in src.findall('./Definition') recursive -%}
						<div class="panel panel-info" id="d{{ def.attrib['fullname'] }}">
							<div class="panel-heading clearfix">
								<div class="panel-title type">
									{{ def.find('./Type').text.upper() }}
								</div>
								<div class="panel-title sign">
									<span class="sign-name">{{ def.find('./Signature').attrib['sign'] }}</span>
								</div>
								<div class="btns pull-right">
									{% if def.attrib['inherit_type'] != 'local' %}
									<span class="inherit_type"> {{ def.attrib['inherit_type'].upper() }}</span>
									{% endif %}
									<a href="#ecldoc-section-tree" data-toggle="#t-{{ def.attrib['fullname'] }}" class="tree-link glyphicon glyphicon-menu-up"></a>
								</div>
							</div>

							<div class="panel-body">
								{% if def.find('./Documentation') -%}
								<div class="row">
									<div class="col-md-12" style="padding-bottom: 10px;">
										{{ def.find('./Documentation').find('./content').text }}
									</div>
								</div>
								{% if def.find('./Documentation').find('./param') %}
								<div class="row">
									<div class="col-md-1 doc-type">Parameters</div>
									<div class="col-md-11">
										<table class="table">
											{% for tag in def.find('./Documentation').findall('./param') -%}
											<tr>
												<td style="width: 20%; font-weight: bold;">{{ tag.find('./name').text }}</td>
												<td>{{ tag.find('./desc').text }}</td>
											</tr>
											{% endfor -%}
										</table>
									</div>
								</div>
								{% endif %}
								{% if def.find('./Documentation').findall('return') %}
								<div class="row">
									<div class="col-md-1 doc-type">Returns</div>
									<div class="col-md-11">
										<table class="table">
											{% for tag in def.find('./Documentation').findall('./return') -%}
											<tr>
												<td>{{ tag.text }}</td>
											</tr>
											{% endfor -%}
										</table>
									</div>
								</div>
								{% endif %}
								{% if def.find('./Documentation').find('./field') %}
								<div class="row">
									<div class="col-md-1 doc-type">Fields</div>
									<div class="col-md-11">
										<table class="table">
											{% for tag in def.find('./Documentation').findall('./field') -%}
											<tr>
												<td width="20%"><b>{{ tag.find('./name').text }}</b> </td>
												<td>{{ tag.find('./desc').text }}</td>
											</tr>
											{% endfor -%}
										</table>
									</div>
								</div>
								{% endif %}
								{% endif -%}
							</div>
							<div class="panel-footer">
								{% if def.find('./Documentation') -%}
								{% if def.find('./Documentation').findall('./see') -%}
								<div class="row">
									<div class="col-md-1">Also See</div>
									<div class="col-md-11">
										<ul>
											{% for tag in def.find('./Documentation').findall('./see') -%}
											<li><b>{{ tag.text }}</b></li>
											{% endfor -%}
										</ul>
									</div>
								</div>
								{% endif -%}
								{% endif -%}

								{% if def.find('./Parents') -%}
								<div class="row">
									<div class="col-md-1">Parent</div>
									<div class="col-md-11">
										<ul>
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
						</div>
						{{ loop(def.findall('./Definition')) }}
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
	<script>
		$(document).ready(function(){
			$('.tree-link').click(function(e) {
				var loc = $(this).attr('data-toggle');
				$(loc).parents('.tree').collapse('show');
			});
		});
	</script>
</body>
</html>