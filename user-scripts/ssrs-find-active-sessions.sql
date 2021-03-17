/*
SSRS Find Active Session Information
3/11/2014 JCD
Uses standard DB names [ReportServer] and [ReportServerTempDB]
Tested: SQL 2005, SQL 2008 R2 and SQL 2012
*/
SET NOCOUNT ON 
GO
SELECT 
       CONVERT(VARCHAR(20),s.[CreationTime],22) [SessionStart]
	  ,u.[UserName]
	  ,c.[name] [Report]
	  ,d.[name] [DataSource]
      ,s.[ReportPath]
      ,s.[EffectiveParams]
	  ,DATEDIFF(minute,s.[CreationTime],GETDATE()) [RunningTimeMinutes]
FROM  [ReportServerTempDB].[dbo].[SessionData]  as s with (NOLOCK)
JOIN   [ReportServer].[dbo].[Catalog]  as c with(NOLOCK)
	ON c.path= s.reportPath
JOIN [ReportServer].[dbo].[DataSource]  as d with(NOLOCK)
  ON c.ItemID = d.ItemID
JOIN [ReportServer].[dbo].[Users] as u with(NOLOCK) 
	on u.UserId = s.ownerID
ORDER BY s.[CreationTime];
GO