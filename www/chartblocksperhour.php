<?php include_once("config.php") ?>
<?php include_once("functions.php") ?>
<script type="text/javascript">
google.charts.load('current', {packages: ['corechart', 'bar']});
google.charts.setOnLoadCallback(drawChart);

function drawChart() {
	var data = new google.visualization.DataTable();
	data.addColumn('timeofday', 'Hour');
	data.addColumn('number', 'Blocks');
	data.addRows([<?php include_once("chartblocksperhourdata.php") ?>]);

	var chart = new google.visualization.ColumnChart(document.getElementById('chart_blocksperhour_staticdata'));
	  chart.draw(data, {
		width: 350,
		height: 200,
		legend: 'none',
		colors: ['#000000']
	  });
}	
</script>
