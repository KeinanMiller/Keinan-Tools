--needs fixed with second join

SELECT
    RELAYOUTPT.OUTPUTID - 16 AS Output_Address,
    RELAYOUTPT.NAME AS OutPut_Name,
    ALARMPANEL.NAME as Board_Name

FROM RELAYOUTPT

