# RPIAdmin
Useful Scrits for RPI Administrators

1. RPIShutdownGraceful.ps1 - This powershell script can be used to gracefully shutdown an RPI node. Useful, for example, for automating shutdown of the environment during OS patching. 
2. RPIHangingTasksSP.sql - this creates a stored procedure on the Pulse database named 'rpHngcnt'. This counts the number of hung system tasks and can be used/modified as part of a monitor or can be used in conjunction with the powershell script restartTM.ps1 to restart TaskManager when a system task is hung
3. restartTM.ps1 - This powershell script restarts task manager if there are hung tasks based on the results of stored procedure 'rpHngcnt'
