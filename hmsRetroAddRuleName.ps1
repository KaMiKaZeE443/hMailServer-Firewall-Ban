<#
_  _ _  _  _  _ _    ____ ____ ____ _  _ ____ ____     
|__| |\/| /_\ | |    [__  |___ |__/ |  | |___ |__/     
|  | |  |/   \| |___ ___] |___ |  \  \/  |___ |  \     
____ _ ____ ____ _ _ _  _  _    _       ___   _  _  _ 
|___ | |__/ |___ | | | /_\ |    |       |__] /_\ |\ | 
|    | |  \ |___ |_|_|/   \|___ |___    |__]/   \| \| 

.SYNOPSIS
	Powershell script to retroactively add firewall rule names

.DESCRIPTION
	Adds column "rulename" to database, queries firewall for rules, extracts IP scope from rules and inserts rule name into database for each IP. 
	
.FUNCTIONALITY
	1) Fill in user variables
	2) Run script

.NOTES
	Includes email notification when complete. Also includes a search for bans with no rules to bring the firewall up to match the database.

.EXAMPLE

#>

<# https://stackoverflow.com/a/422529 #>
Function Parse-IniFile ($file) {
	$ini = @{}

	$section = "NO_SECTION"
	$ini[$section] = @{}

	switch -regex -file $file {
		"^\[(.+)\]$" {
			$section = $matches[1].Trim()
			$ini[$section] = @{}
		}
		"^\s*([^#].+?)\s*=\s*(.*)" {
			$name,$value = $matches[1..2]
			if (!($name.StartsWith(";"))) {
				$ini[$section][$name] = $value.Trim()
			}
		}
	}
	$ini
}

Function MySQLQuery($Query) {
	$Today = (Get-Date).ToString("yyyyMMdd")
	$DBErrorLog = "$PSScriptRoot\$Today-DBError-RetroRuleAdd.log"
	$ConnectionString = "server=" + $ini['Database']['Host'] + ";port=3306;uid=" + $ini['Database']['Username'] + ";pwd=" + $ini['Database']['Password'] + ";database=" + $ini['Database']['DBase']
	Try {
		[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
		$Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$Connection.ConnectionString = $ConnectionString
		$Connection.Open()
		$Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
		$DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
		$DataSet = New-Object System.Data.DataSet
		$RecordCount = $dataAdapter.Fill($dataSet, "data")
		$DataSet.Tables[0]
	}
	Catch {
		Write-Output "$((get-date).ToString(`"yy/MM/dd HH:mm:ss.ff`")) : ERROR : Unable to run query : $query `n$Error[0]" | out-file $DBErrorLog -append
	}
	Finally {
		$Connection.Close()
	}
}

Function EmailResults {
	$Subject = "Retroactive Rule Name Results" 
	$Body = (Get-Content -Path $Msg | Out-String )
	$SMTPClient = New-Object Net.Mail.SmtpClient($ini['Email']['SMTPServer'], $ini['Email']['SMTPPort']) 
	$SMTPClient.EnableSsl = [System.Convert]::ToBoolean($ini['Email']['SSL'])
	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($ini['Email']['SMTPAuthUser'], $ini['Email']['SMTPAuthPass']); 
	$SMTPClient.Send($ini['Email']['FromAddress'], $ini['Email']['Recipient'], $Subject, $Body)
}

<#  https://gist.github.com/Stephanevg/a951872bd13d91c0eefad7ad52994f47  #>
Function Get-NetshFireWallrule {
	Param(
		[String]$RuleName
	)
	$Rules = & netsh advfirewall firewall show rule name="$ruleName"
	$return = @()
		$HAsh = [Ordered]@{}
		foreach ($Rule in $Rules){
			switch -Regex ($Rule){
				'^Rule Name:\s+(?<RuleName>.*$)'{$Hash.RuleName = $MAtches.RuleName}
				'^RemoteIP:\s+(?<RemoteIP>.*$)'{$Hash.RemoteIP = $Matches.RemoteIP;$obj = New-Object psobject -Property $Hash;$return += $obj}
			}
		}
	return $return
}

#	Load User Variables
$ini = Parse-IniFile("$PSScriptRoot\Config.INI")

$StartTime = (Get-Date -f G)

#	Create folder if it doesn't exist
If (-not(Test-Path "$PSScriptRoot\RetroAddRuleName")) {
	md "$PSScriptRoot\RetroAddRuleName"
}

$NewLine = [System.Environment]::NewLine
$RegexIP = '^(([0-9]{1,3}\.){3}[0-9]{1,3})$'
$RegexDateName = 'hms\sFWBan\s20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$'
$RegexIPName = '^(([0-9]{1,3}\.){3}[0-9]{1,3})$'
$RegexFileName = 'hms\sFWBan\s20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9].txt$'
$Location = "$PSScriptRoot\RetroAddRuleName"

Get-NetshFireWallrule ("all") | ForEach {
	If (($_.RuleName -match $RegexDateName) -or ($_.RuleName -match $RegexIPName)){
		$RuleName = $_.RuleName
		Get-NetshFireWallrule ("$RuleName") | ForEach {
			$RemoteIP = $_.RemoteIP
			$ReplaceCIDR = ($RemoteIP).Replace("/32", "")
			$ReplaceNL = ($ReplaceCIDR).Replace(",", $NewLine)
			Write-Output $ReplaceNL
		} | Out-File "$Location\$RuleName.txt"
	}
}

Get-ChildItem $Location | Where-Object {$_.name -match $RegexFileName} | ForEach {
	$RuleFileName = $_.name
	$SQLRuleName = ($RuleFileName).Replace(".txt", "")
	Get-Content -Path "$Location\$RuleFileName" | ForEach {
		If ($_ -match $RegexIP){
			$IP = $_
			$Query = "UPDATE hm_fwban SET rulename = '$SQLRuleName' WHERE ipaddress = '$IP'"
			MySQLQuery($Query)
		}
	}
}

# 	Add "rulename" column to hm_fwban
$Query = "ALTER TABLE hm_fwban ADD rulename VARCHAR(192) NULL AFTER helo;"
MySQLQuery($Query)

#	Pick up any missed entries (bans without firewall rules)
$Query = "SELECT ipaddress, id FROM hm_fwban WHERE flag IS NULL AND rulename IS NULL"
MySQLQuery $Query | foreach {
	$ID = $_.id
	$IP = $_.ipaddress
	& netsh advfirewall firewall add rule name="$IP" description="Rule added $((get-date).ToString('MM/dd/yy'))" dir=in interface=any action=block remoteip=$IP
	$Query = "UPDATE hm_fwban SET rulename='$IP' WHERE id='$ID'"
	MySQLQuery $Query
}

$EndTime = (Get-Date -f G)
$OperationTime = New-Timespan $StartTime $EndTime
If (($Duration).Hours -eq 1) {$sh = ""} Else {$sh = "s"}
If (($Duration).Minutes -eq 1) {$sm = ""} Else {$sm = "s"}
If (($Duration).Seconds -eq 1) {$ss = ""} Else {$ss = "s"}

$Msg = ("Retroactive RuleName update complete.`n`nUpdate completed in {0:%h} hour$sh {0:%m} minute$sm {0:%s} second$ss" -f $OperationTime)
EmailResults