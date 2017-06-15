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
						<div class="row">
							<div class="col-lg-4">
								<a href="#menu-toggle" class="glyphicon glyphicon-menu-hamburger" style="font-size:2.2em;" id="menu-toggle"></a>
							</div>
							<div class="col-lg-8">
								<h1>{{ name }}</h1>
							</div>
						</div>
						<div class="row">
							<div class="col-lg-12">
								<ul>
									{% for d in files %}
									<li>
										<a href="{{ d.target }}">{{ d.name }}</a>
									</li>
									{% endfor %}
								</ul>
							</div>
						</div>
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