USE [UtilityDB] --or whatever DB has access to interaction db
GO

/****** Object:  StoredProcedure [dbo].[rpiHangWF]    Script Date: 2/24/2016 5:35:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[rpiHangWF] AS



IF OBJECT_ID('#tempRPIMON') IS NOT NULL
BEGIN
	DROP TABLE #tempRPIMON
END

DECLARE @hangthreshold INT --How many hours to consider workflow hanging
SELECT @hangthreshold = 3

SELECT * INTO #tempRPIMON FROM
(
-- First get all parents that do not have children and are hanging.
-- For some reason, timestamps in RPI DB stored as GMT, so need to adjust
SELECT iw.WorkflowAssociationInstanceID      AS 'ID',
       iw.InteractionName                    AS 'Parent Name', 
       iw.[Status]                           AS 'Parent Status', 
       CAST(
	     DATEADD(hh, 
		  DATEDIFF(hh, GETUTCDATE(), 
		   GETDATE()), 
			iw.LastEventTimestamp) 
			    AS VARCHAR)                  AS 'Parent Last TimeStamp', 
       iw.UserName                           AS 'Parent User', 
       'N/A'                                 AS 'Child User', 
       'N/A'                                 AS 'Child Process', 
       'N/A'                                 AS 'Child Last TimeStamp', 
       'N/A'                                 AS 'Child Status' 
FROM   [Interaction_RPG].[dbo].op_InteractionWorkflows iw 
       LEFT OUTER JOIN [Interaction_RPG].[dbo].op_DataWorkflows dw WITH (NOLOCK)
                    ON iw.WorkflowAssociationInstanceID = 
                       dw.WorkflowAssociationInstanceID 
WHERE  dw.WorkflowAssociationInstanceID IS NULL 
       AND DATEDIFF(hh, 
	          DATEADD(hh, 
				DATEDIFF(hh, GETUTCDATE(), 
				  GETDATE()), 
					iw.LastEventTimestamp), GETDATE()) >= @hangthreshold
       AND iw.[DynamicStatus] IN ( 'Playing', 'ResumePlayRequested', 'PlayRequested' ) 
       AND iw.IsSandBox = 0 

-- Let's add parent Workflows with child steps that are hanging
UNION ALL

SELECT iw.WorkflowAssociationInstanceID, 
       iw.InteractionName                           AS 'Parent Name', 
       iw.[Status]                                  AS 'Parent Status', 
       CAST(
	     DATEADD(hh, 
		  DATEDIFF(hh, GETUTCDATE(), 
		   GETDATE()), 
			iw.LastEventTimestamp) 
			    AS VARCHAR)                         AS 'Parent Last TimeStamp', 
       iw.UserName                                  AS 'Parent User', 
       dw.UserName                                  AS 'Child User', 
       dw.ProcessName                               AS 'Child Process', 
       CAST(
	     DATEADD(hh, 
		   DATEDIFF(hh, GETUTCDATE(), 
		     GETDATE()),
			    dw.LastEventTimestamp) AS VARCHAR)  AS 'Child Last TimeStamp', 
       dw.[Status]                                  AS 'Child Status' 
FROM   [Interaction_RPG].[dbo].op_InteractionWorkflows iw 
       INNER JOIN [Interaction_RPG].[dbo].op_DataWorkflows dw WITH (NOLOCK) 
                    ON iw.WorkflowAssociationInstanceID = 
                       dw.WorkflowAssociationInstanceID 
WHERE  DATEDIFF(hh, 
	     DATEADD(hh, 
		    DATEDIFF(hh, GETUTCDATE(), 
			  GETDATE()), 
			    dw.LastEventTimestamp), GETDATE()) >= @hangthreshold
       AND dw.[DynamicStatus] IN ( 'Playing', 'ResumePlayRequested', 'PlayRequested' ) 
       AND dw.IsSandBox = 0 
	   AND DATEADD(hh,-1,GETDATE()) > dw.NextTriggerTime


--hanging parent trigger
UNION ALL 

SELECT iw.WorkflowAssociationInstanceID, 
       iw.InteractionName                           AS 'Parent Name', 
       iw.[Status]                                  AS 'Parent Status', 
       CAST(
	     DATEADD(hh, 
		  DATEDIFF(hh, GETUTCDATE(), 
		   GETDATE()), 
			iw.LastEventTimestamp) 
			    AS VARCHAR)                         AS 'Parent Last TimeStamp', 
       iw.UserName                                  AS 'Parent User', 
       dw.UserName                                  AS 'Child User', 
       dw.ProcessName                               AS 'Child Process', 
       CAST(
	     DATEADD(hh, 
		   DATEDIFF(hh, GETUTCDATE(), 
		     GETDATE()),
			    dw.LastEventTimestamp) AS VARCHAR)  AS 'Child Last TimeStamp', 
       dw.[Status]                                  AS 'Child Status' 
FROM   [Interaction_RPG].[dbo].op_InteractionWorkflows iw 
       INNER JOIN [Interaction_RPG].[dbo].op_DataWorkflows dw WITH (NOLOCK) 
                    ON iw.WorkflowAssociationInstanceID = 
                       dw.WorkflowAssociationInstanceID 
WHERE  
       iw.[Status] IN ( 'Playing', 'ResumePlayRequested', 'PlayRequested' )
	   AND dw.[DynamicStatus] NOT IN ('Completed', 'Paused', 'Failed')
       AND iw.IsSandBox = 0

	   AND DATEDIFF(hh, 
	     DATEADD(hh, 
		    DATEDIFF(hh, GETUTCDATE(), 
			  GETDATE()), 
			    dw.LastEventTimestamp), GETDATE()) >= @hangthreshold

	    AND DATEADD(hh,-1,GETDATE()) > dw.NextTriggerTime
		
		
) AS CTE_dummy


DECLARE @wfcount INT;
SELECT @wfcount = COUNT(*) FROM #tempRPIMON

IF @wfcount >=1
BEGIN
	DECLARE @tableHTML  NVARCHAR(MAX);
	SET @tableHTML =		
	N'<H3>RPMKTG RPI - Hanging Workflows Alert</H3><br><br>' +
    N'<H3>The following workflows have not had an update in ' + CAST(@hangthreshold AS VARCHAR) + ' hour(s):</H3>' +
    N'<table border="1" width="700">' +
	N'<tr><th>User Name</th><th>Parent WF Name</th>' +
    N'<th>Parent Status</th><th>Parent Last TimeStamp</th>' +
	N'<th>Child Task Name</th><th>Child Status</th><th>Child Last TimeStamp</th></tr>' +
	
    CAST ( ( SELECT DISTINCT td = [Parent User], '',
                    td = [Parent Name], '',
                    td = [Parent Status], '',
                    td = [Parent Last TimeStamp], '',
                    td = [Child Process], '',
					td = [Child Status], '',
                    td = [Child Last TimeStamp], ''					
              FROM #tempRPIMON            
              FOR XML PATH('tr'), TYPE)
    AS NVARCHAR(MAX) ) +
	N'</table>' ;
	
    EXEC msdb.dbo.SP_SEND_DBMAIL
    @profile_name='rpmktgmail',
    @recipients='',
    @subject = 'RPMKTG - Hanging Workflows Alert',
    @body = @tableHTML,
    @body_format = 'HTML';
END 


DROP TABLE #tempRPIMON




GO


