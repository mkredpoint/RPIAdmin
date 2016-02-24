 - # this powershell script can be used to gracefully stop an RPI node
# Notes: Set $wfHost according to the node you want to gracefully shutdown
#        Set $SqlConnection.ConnectionString according to your environment
#        You may want to increase $retryMax and $retrySleep
#        

$logfile = "C:\Temp\rpi_services_stop_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
$wfHost = 1 # set to the workflow host ID for your node 

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=.;Database=Pulse;Integrated Security=True"
$SqlConnection.Open()
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = "Update dbo.rpi_WorkflowHosts Set [Status] = 'PauseRequested', [IsCheckedIn] = 0 Where WorkflowHostID = $($wfHost) AND [Status]= 'Running'"
$SqlCmd.Connection = $SqlConnection
$SqlCmd.ExecuteNonQuery()
$retryCnt = 0
$retryMax = 5
$retrySleep = 20
$completed = $false

$SqlCmd.CommandText = "SELECT [Status] from dbo.rpi_WorkflowHosts Where WorkflowHostID = $($wfHost)"

while (-not $completed) 
 {
	$rpHstStat = $SqlCmd.ExecuteScalar()
	"The status of workflow host is $($rpHstStat)" | out-file -Filepath $logfile -append
	if ($rpHstStat -ne "Paused")
	{
		if ($retryCnt -eq $retryMax)
		{
			"We've hit the retry maximum breaking out" | out-file -Filepath $logfile -append
			 $SqlConnection.Close()
			exit
		}
		
		"RPI is not paused. Sleeping for $($retrySleep) seconds" | out-file -Filepath $logfile -append
		$retryCnt =+ 1
		"This is my retry count: $($retryCnt)" | out-file -Filepath $logfile -append
		Start-Sleep $retrySleep
	}
	else
	{		
	    "Stopping RPI Services" | out-file -Filepath $logfile -append
		$rpServices = "ResonanceTaskManagerService", "ResonanceWorkflowManager", "ResonanceNodeManager"
		
		foreach ($rpService in $rpServices)	
		{
			$serviceinfo = Get-Service $rpService
			if ($serviceinfo.Status -eq 'Running')
			{
				"Stopping Service: $($rpService)" | out-file -Filepath $logfile -append
				Stop-Service $rpService
        
			}
		}
		
		$completed = $true
	}

 }
 
 
 $SqlConnection.Close()
