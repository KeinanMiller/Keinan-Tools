

SELECT
    ALARMINPUT.INPUTID AS Input_Address,
    ALARMINPUT.NAME AS Input_Name,
    ALARMPANEL.NAME AS Board_Name,
    CASE ALARMINPUT.SUPERVISION  
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default setting or non-standard'
    END AS Supervision

FROM ALARMINPUT

