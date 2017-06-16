<!DOCTYPE html>
<html lang="en">

<head>

	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width, shrink-to-fit=no, initial-scale=1">
	<title>{{ name }}</title>
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
			<div class="navbar-header" style="margin-left : 20px;">
				<span class="navbar-brand">{{ name }}</span>
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
				<div class="row">
					<div class="col-lg-12">
						<table class="table">
							{% for d in files %}
							<tr>
								<td>
									{% if d.type == 'file' %}
									<span class="glyphicon glyphicon-file"></span>
									{% else %}
									<span class="glyphicon glyphicon-folder-close"></span>
									{% endif %}
								</td>
								<td><a href="{{ d.target }}">{{ d.name }}</a></td>
							</tr>
							{% endfor %}
						</table>
					</div>
				</div>
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
				var loc = $(this).attr('href');
				$(loc).parents().collapse('show');
				return true;
			});
		});
	</script>
</body>
</html>