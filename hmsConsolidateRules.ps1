<#
_  _ _  _  _  _ _    ____ ____ ____ _  _ ____ ____     
|__| |\/| /_\ | |    [__  |___ |__/ |  | |___ |__/     
|  | |  |/   \| |___ ___] |___ |  \  \/  |___ |  \     
____ _ ____ ____ _ _ _  _  _    _       ___   _  _  _ 
|___ | |__/ |___ | | | /_\ |    |       |__] /_\ |\ | 
|    | |  \ |___ |_|_|/   \|___ |___    |__]/   \| \| 

.SYNOPSIS
	Powershell script to consolidate firewall rules

.DESCRIPTION
	Consolidates rules from one firewall rule per IP to one firewall rule per day containing all IPs for the previous day

.FUNCTIONALITY
	* Queries database for previous day's bans
	* Creates new firewall containing all of previous day's banned IPs 
	* Deletes all of previous day's one-IP-per firewall rules

.NOTES
	* Create scheduled task to run once per day at 12:01 am
	
.EXAMPLE

#>

# Include required files
Try {
	.("$PSScriptRoot\Config.ps1")
	.("$PSScriptRoot\CommonCode.ps1")
}
Catch {
	Write-Output "$((get-date).ToString(`"yy/MM/dd HH:mm:ss.ff`")) : ERROR : Unable to load supporting PowerShell Scripts : $query `n$Error[0]" | out-file "$PSScriptRoot\PSError.log" -append
}

#	Create ConsolidateRules folder if it doesn't exist
If (-not(Test-Path "$PSScriptRoot\ConsolidateRules")) {
	md "$PSScriptRoot\ConsolidateRules"
}

#	Get BanDate (Yesterday) and establish csv
$BanDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")

$Query = "SELECT COUNT(id) AS countid FROM hm_fwban WHERE $(DBCastDateTimeFieldAsDate('timestamp')) LIKE '$BanDate%' AND flag IS NULL"
RunSQLQuery $Query | ForEach {
	[int]$CountIP = $_.countid
}

$NewLine = [System.Environment]::NewLine
$N = 0
$Rows = 400
$Limit = [math]::ceiling($CountIP / $Rows)

Do {
	$X = ($N).ToString("000")
	$ConsRules = "$PSScriptRoot\ConsolidateRules\hmsFWBRule-"+$BanDate+"_"+$X+".csv"
	$Query = "
		SELECT ipaddress 
		FROM hm_fwban 
		WHERE $(DBCastDateTimeFieldAsDate('timestamp')) LIKE '$BanDate%' AND flag IS NULL 
		ORDER BY timestamp DESC
		$(DBLimitRowsWithOffset $($N * $Rows) $Rows)
	"
	RunSQLQuery $Query | Export-CSV $ConsRules
	
	$N++
}
Until ($N -eq $Limit)

$Location = "$PSScriptRoot\ConsolidateRules"
$RegexName = 'hmsFWBRule\-202[0-9]\-[0-9][0-9]\-[0-9][0-9]_[0-9]{3}\.csv$'
$RegexIP = '(([0-9]{1,3}\.){3}[0-9]{1,3})'
Get-ChildItem $Location | Where-Object {$_.name -match $RegexName} | ForEach {
	$FileName = $_.name
	$FilePathName = "$Location\$FileName"
	$RuleName = ($FileName).Replace(".csv", "")
	import-csv -Path $FilePathName | ForEach {
		$IP = $_.ipaddress
		$Query = "UPDATE hm_fwban SET rulename = '$RuleName' WHERE ipaddress = '$IP'"
		RunSQLQuery($Query)
		Write-Output $IP
	}  | Out-File "$FilePathName.txt"

	#	Make sure txt file path exists
	If (Test-Path "$FilePathName.txt"){
		$RuleData = Get-Content "$FilePathName.txt" | Select-Object -First 1
		#	Make sure txt file is populated with IP data (if not, you'll have a rule banning all local and all remote IPs)
		If ($RuleData -match $RegexIP){

			#	Replace all newlines and last comma in order to create a single string that can be used to populate firewall rule remoteaddress	
			$NL = [System.Environment]::NewLine
			$Content=[String] $Template= [System.IO.File]::ReadAllText("$FilePathName.txt")
			$Content.Replace($NL,",") | Out-File "$FilePathName.rule.txt"
			(Get-Content -Path "$FilePathName.rule.txt") -Replace ',$','' | Set-Content -Path "$FilePathName.rule.txt"

			#	Add firewall rule with string containing all IPs from yesterday's bans
			& netsh advfirewall firewall add rule name="$RuleName" description="FWB Rules for $BanDate" dir=in interface=any action=block remoteip=$(Get-Content "$FilePathName.rule.txt")

			#	Read csv and delete each of yesterday's individual IP firewall rules
			Import-CSV $FilePathName | ForEach {
				$IP = $_.ipaddress
				& netsh advfirewall firewall delete rule name=`"$IP`"
			}
		}
	}
}