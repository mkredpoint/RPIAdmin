-- Stored procedure can be used as part of a monitor 
-- or can be used in conjuntion with powershell script restartTM.ps1
-- in order to restart task manager if one of the tasks is hanging.
-- NextFireTime gets written when the task wakes up to run.
-- I put in a 20 minute buffer in case it's job that takes several minutes to run.
-- Optionally, qualify with actually tasks you are interested in monitoring for

CREATE PROCEDURE [dbo].[rpHngcnt]
AS
 
SELECT COUNT(*)
FROM
[Pulse].[dbo].[rpi_Tasks] rpt WITH (NOLOCK)
 
WHERE
DateAdd(mi,-20,GETDATE()) > NextFireTime  -- optionally add specific tasks: AND TaskName in ('Load web cache data', 'Web events importer', 'Web form processor')
AND
isEnabled = 1
RETURN