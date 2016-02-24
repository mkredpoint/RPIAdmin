# Powershell script to restart task manager if there are hung tasks.
# Needs to be run in conjunction with a stored procedure named rpHngcnt
# Set $SqlConnection.ConnectionString accordingly
#

$logfile = "C:\Temp\rpi_services_restart_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"

function Exec-Sproc{
	param($Conn, $Sproc, $Parameters=@{})

	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandType = [System.Data.CommandType]::StoredProcedure
	$SqlCmd.Connection = $Conn
	$SqlCmd.CommandText = $Sproc
	foreach($p in $Parameters.Keys){
 		[Void] $SqlCmd.Parameters.AddWithValue("@$p",$Parameters[$p])
 	}
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmd)
	$DataSet = New-Object System.Data.DataSet
	[Void] $SqlAdapter.Fill($DataSet)
	$SqlConnection.Close()
	return $DataSet.Tables[0]
}

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=.;Database=Pulse;Integrated Security=True"

$Res = Exec-Sproc -Conn $SqlConnection -Sproc "rpHngcnt"

$service = 'ResonanceTaskManagerService'
$serviceinfo = Get-Service $service

foreach ($Row in $Res)
{
 if ($Row[0] -gt 0) 
 {


    if ($serviceinfo.Status -eq 'Running')
    {
        "Restarting service: $($service)" | out-file -Filepath $logfile -append
        Restart-Service $service -force
        break
    }
    else
    {
        exit
    }
	exit
 }

}


