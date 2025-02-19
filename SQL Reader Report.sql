--used to pull reader report needs to add panel type in future update 
USE ACCESSCONTROL
SELECT 

	READERDESC as ReaderName, 
    	COMMADDR as ReaderAddress, 
	READER_NUMBER as ReaderNumber,

CASE PORTNUM
	WHEN 0 THEN 'Onboard Reader'
        WHEN 11 THEN 'Reader 1'
        WHEN 78 THEN 'IP addressed'
	ELSE CAST(PORTNUM AS VARCHAR(10))
END AS Port_Number,
	
    CASE CTRLTYPE 
        WHEN 112 THEN 'LNL-1300'
        WHEN 115 THEN 'LNL-1320'
        WHEN 118 THEN 'LNL-1320'
	WHEN 20 THEN 'LNL-1320 OSDP'
	WHEN 21 THEN 'LNL-1300 OSDP'
        WHEN 159 THEN 'Onboard Reader'
	WHEN 36 THEN 'Onboard Reader'
        ELSE 'Other' 
    END AS Controller_Type,

	
    CASE DOORCONTACT_SUPERVISION 
	WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard' 
    END AS DoorContact_Supervision,

    CASE REX_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard' 
    END AS REX_Supervision,

    AUX1NAME as Aux1_Name,

    CASE AUX1_SUPERVISION 
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard' 
    END AS AUX1_Supervision,

    AUX2NAME as Aux2_Name, 

    CASE AUX2_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard' 
    END AS AUX2_Supervision,

    OUT1NAME as Output1_Name, 
    OUT2NAME as OutPut2_Name, 	
	

	AccessPane.NAME as Panel_Name

FROM READER 
JOIN AccessPane ON READER.PANELID = AccessPane.PANELID 
ORDER BY AccessPane.NAME, PORTNUM, COMMADDR, READER_NUMBER;
