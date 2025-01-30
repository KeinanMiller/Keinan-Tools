--used to pull info on all alarm panel via sql query.
USE ACCESSCONTROL
SELECT
	 ALARMPANEL.NAME as Panel_Name, 
	CASE PORTNUMBER
		WHEN 0 THEN 'Onboard Reader'
		WHEN 11 THEN 'Reader 1'
		WHEN 78 THEN 'IP addressed'
		ELSE CAST(PORTNUMBER AS VARCHAR(10))
	END AS Port_Number,
	 COMMADDR AS Panel_Address,
	CASE CTRLTYPE
		 WHEN 129 THEN '1100 Board'
		WHEN 130 THEN '1200 Board'
		 ELSE 'UNKNOWN'
	 END as Panel_Type,

	AccessPane.NAME as ISC_Name  


FROM ALARMPANEL

JOIN AccessPane ON ALARMPANEL.PANELID = AccessPane.PANELID
ORDER BY AccessPane.NAME, PORTNUMBER, COMMADDR
