# this powershell script can be used to gracefully stop an RPI node
# Note: set $wfHost according to the node you want to gracefully shutdown
#       also, you may want to increase retry and sleep time

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
		#TaskManager
		$serviceTM = 'ResonanceTaskManagerService'
		$serviceinfoTM = Get-Service $serviceTM
		if ($serviceinfoTM.Status -eq 'Running')
		{
			"Stopping Service: $($serviceTM)" | out-file -Filepath $logfile -append
			 Stop-Service $serviceTM
        
		}
		#Workflow Manager
		$serviceWM = 'ResonanceWorkflowManager'
		$serviceinfoWM = Get-Service $serviceWM
		if ($serviceinfoWM.Status -eq 'Running')
		{
			"Stopping service: $($serviceWM)" | out-file -Filepath $logfile -append
			 Stop-Service $serviceWM
        
		}
		#NodeManager
		$serviceNM = 'ResonanceNodeManager'
		$serviceinfoNM = Get-Service $serviceNM
		if ($serviceinfoNM.Status -eq 'Running')
		{
			"Stopping service: $($serviceNM)" | out-file -Filepath $logfile -append
			 Stop-Service $serviceNM -force
        
		}
		
		$completed = $true
	}

 }
 
 
 $SqlConnection.Close()
