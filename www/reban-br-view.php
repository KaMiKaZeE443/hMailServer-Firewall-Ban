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
	if (isset($_GET['ban_reason'])) {$ban_reason = $_GET['ban_reason'];} else {$ban_reason = "";}

	if (empty($ban_reason)){
		echo "<br /><br />Error: No IP entries for ban reason ".$ban_reason."<br /><br />";
	} else {

		$no_of_records_per_page = 20;
		$offset = ($page-1) * $no_of_records_per_page;
		$total_pages_sql = $pdo->prepare("
			SELECT 
				Count( * ) AS count 
			FROM hm_fwban 
			WHERE ban_reason LIKE '{$ban_reason}' AND (flag=1 OR flag=2)
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
				flag, 
				helo 
			FROM hm_fwban 
			WHERE ban_reason LIKE '{$ban_reason}' AND (flag=1 OR flag=2) 
			".DBLimitRowsWithOffset('TimeStamp','DESC',0,0,$offset,$no_of_records_per_page)
		);
		$sql->execute();

		if ($total_rows == 1){$singular = '';} else {$singular= 's';}
		if ($total_rows == 0){
			echo "<br /><br />No previously released results for ban reason \"<b>".$ban_reason."</b>\"";
		} else {
			echo "<h2>What would you like to ban?</h2>";
			echo "Click \"YES\" under column \"RS\" to re-ban a single address.<br /><br />";
			echo "<a href=\"./reban-br.php?submit=Reban&ban_reason=".$ban_reason."\" onclick=\"return confirm('Are you sure you want to re-ban all released IPs for ".$ban_reason."?')\">Click here</a> to re-ban all.<br />";
			echo "<br /><br />";
			echo "Results for released IPs for ban reason \"<b>".$ban_reason."</b>\": ".number_format($total_rows)." IP".$singular." (Page: ".number_format($page)." of ".number_format($total_pages).")<br />";
			echo "<table class='section'>
				<tr>
					<th>Timestamp</th>
					<th>IP Address</th>
					<th>Reason</th>
					<th>Country</th>
					<th>HELO</th>
					<th>RS</th>
				</tr>";
			while($row = $sql->fetch(PDO::FETCH_ASSOC)){
				echo "<tr>";

				echo "<td>".$row['TimeStamp']."</td>";
				echo "<td><a href=\"search.php?submit=Search&search=".$row['ipaddress']."\">".$row['ipaddress']."</a></td>";
				echo "<td>".$row['ban_reason']."</td>";
				echo "<td><a href=\"https://ipinfo.io/" . $row['ipaddress'] . "\"  target=\"_blank\">" . $row['country'] . "</a></td>";
				echo "<td>".$row['helo']."</td>";
				if($row['flag'] == 1 || $row['flag'] == 2) echo "<td><a href=\"./reban-ip.php?submit=Reban&ipRange=".$row['ipaddress']."\" onclick=\"return confirm('Are you sure you want to re-ban IP ".$row['ipaddress']."?')\">YES</a></td>";
				else echo "<td>NO</td>";

				echo "</tr>";
			}
			echo "</table>";

			echo "<ul>";
				if($page <= 1){echo "<li>First </li>";} else {echo "<li><a href=\"?submit=Search&ban_reason=".$ban_reason."&page=1\">First </a><li>";}
				if($page <= 1){echo "<li>Prev </li>";} else {echo "<li><a href=\"?submit=Search&ban_reason=".$ban_reason."&page=".($page - 1)."\">Prev </a></li>";}
				if($page >= $total_pages){echo "<li>Next </li>";} else {echo "<li><a href=\"?submit=Search&ban_reason=".$ban_reason."&page=".($page + 1)."\">Next </a></li>";}
				if($page >= $total_pages){echo "<li>Last</li>";} else {echo "<li><a href=\"?submit=Search&ban_reason=".$ban_reason."&page=".$total_pages."\">Last</a></li>";}
			echo "</ul>";
		}
	}
	echo "<br />";
?>
</div>

<?php include("foot.php") ?>