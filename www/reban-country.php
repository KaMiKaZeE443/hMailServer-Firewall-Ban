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
	if (isset($_GET['submit'])){$button = $_GET['submit'];}else{$button = "";}
	if (isset($_GET['country'])){$country = $_GET['country'];} else {$country = "";}

	if (empty($country)){echo "Error: No country selected. Please see administrator.<br /><br />";} 
	else {
		$sqlcount = $pdo->prepare("
			SELECT 
				COUNT(id) AS value_occurrence 
			FROM hm_fwban 
			WHERE country LIKE '%{$country}%' AND (flag=1 OR flag=2)
		");
		$sqlcount->execute();
		$total_rows = $sqlcount->fetchColumn();
		if ($total_rows > 0) { 
			echo "<br />".number_format($total_rows)." hits for <a href=\"search.php?submit=Search&search=".$country."&RS=NO\">".$country."</a> have been re-banned the firewall.<br />";
			$sql = $pdo->prepare("
				SELECT id 
				FROM hm_fwban 
				WHERE country LIKE '%{$country}%' AND (flag=1 OR flag=2)
			");
			$sql->execute();
			while($row = $sql->fetch(PDO::FETCH_ASSOC)){
				$sql_update = $pdo->exec("
					UPDATE hm_fwban SET flag=3 WHERE id = ".$row['id']
				);
			}
		} else {
			echo "<br />Error: No released records for \"<b>".$country."</b>\". Please <a href=\"search.php?submit=Search&search=".$country."\">search release status</a> or check the spelling and try again.";
		}
	}
?>
</div>

<?php include("foot.php") ?>