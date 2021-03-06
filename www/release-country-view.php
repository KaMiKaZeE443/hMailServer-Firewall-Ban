<?php include("head.php") ?>

<div class="section">

<?php
	include_once("config.php");
	include_once("functions.php");

	if (isset($_GET['page'])) {
		$page = $_GET['page'];
		$display_pagination = 1;
	} else {
		$page = 1;
		$total_pages = 1;
		$display_pagination = 0;
	}
	if (isset($_GET['submit'])) {$button = $_GET ['submit'];} else {$button = "";}
	if (isset($_GET['search'])) {$search = $_GET['search'];} else {$search = "";}
	if (isset($_GET['country'])) {$country = $_GET['country'];} else {$country = "";}

	if (empty($country)){
		echo "No country selected. Please try again or see administator.<br><br>";
	} else {

		$no_of_records_per_page = 20;
		$offset = ($page-1) * $no_of_records_per_page;
		$total_pages_sql = $pdo->prepare("
			SELECT 
				Count( * ) AS count 
			FROM hm_fwban 
			WHERE country LIKE '%{$country}%' AND (flag IS NULL OR flag=3)
		");
		$total_pages_sql->execute();
		$total_rows = $total_pages_sql->fetchColumn();
		$total_pages = ceil($total_rows / $no_of_records_per_page);

		$sql = $pdo->prepare("
			SELECT 
				id, 
				".DBFormatDate('timestamp', '%y/%m/%d %T')." as TimeStamp, 
				ipaddress, 
				ban_reason, 
				country, 
				flag 
			FROM hm_fwban 
			WHERE country LIKE '%{$country}%' AND (flag IS NULL OR flag=3) 
			".DBLimitRowsWithOffset('TimeStamp','DESC',0,0,$offset,$no_of_records_per_page)
		);
		$sql->execute();

		if ($total_rows == 1){$singular = '';} else {$singular= 's';}
		if ($total_rows == 0){
			echo "No unreleased results for \"<b>".$country."</b>\"";
		} else {
			echo "<h2>What would you like to release?</h2>";
			echo "Click \"NO\" under column \"RS\" to release a single address.<br><br>";
			echo "<a href=\"./release-country.php?country=".$country."&submit=Release\" onclick=\"return confirm('Are you sure you want to release all IPs for ".$country."?')\">Click here</a> to release all.<br>";
			echo "<br><br>";
			echo "Results for \"<b>".$country."</b>\": ".number_format($total_rows)." IP".$singular." (Page: ".number_format($page)." of ".number_format($total_pages).")<br>";
			echo "<table class='section'>
				<tr>
					<th>Timestamp</th>
					<th>IP Address</th>
					<th>Reason</th>
					<th>Country</th>
					<th>RS</th>
				</tr>";
			while($row = $sql->fetch(PDO::FETCH_ASSOC)){
				echo "<tr>";

				echo "<td>" . $row['TimeStamp'] . "</td>";
				echo "<td><a href=\"search.php?submit=Search&search=".$row['ipaddress']."\">".$row['ipaddress']."</a></td>";
				echo "<td>" . $row['ban_reason'] . "</td>";
				echo "<td><a href=\"https://ipinfo.io/" . $row['ipaddress']."\"  target=\"_blank\">".$row['country']."</a></td>";
				if($row['flag'] === NULL || $row['flag'] == 3) echo "<td><a href=\"./release-ip.php?submit=Release&ipRange=".$row['ipaddress']."\" onclick=\"return confirm('Are you sure you want to release ".$row['ipaddress']."?')\">No</a></td>";
				else echo "<td>YES</td>";

				echo "</tr>";
			}
			echo "</table>";

			if ($total_pages == 1){
				echo "";
			} else {
				echo "<ul>";
					if($page <= 1){echo "<li>First </li>";} else {echo "<li><a href=\"?submit=Search&country=".$country."&page=1\">First </a><li>";}
					if($page <= 1){echo "<li>Prev </li>";} else {echo "<li><a href=\"?submit=Search&country=".$country."&page=".($page - 1)."\">Prev </a></li>";}
					if($page >= $total_pages){echo "<li>Next </li>";} else {echo "<li><a href=\"?submit=Search&country=".$country."&page=".($page + 1)."\">Next </a></li>";}
					if($page >= $total_pages){echo "<li>Last</li>";} else {echo "<li><a href=\"?submit=Search&country=".$country."&page=".$total_pages."\">Last</a></li>";}
				echo "</ul>";
			}
		}
	}
	echo "<br>";
?>
</div>

<?php include("foot.php") ?>