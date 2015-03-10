UPDATE invbook_writeoff_bases wb
LEFT JOIN invbook_writeoffs wo ON wb.writeoff_id = wo.writeoff_id
SET wb.invbook_definition_id = wo.invbook_definition_id,
wb.timestamp_updated = wb.timestamp_updated
WHERE wb.invbook_definition_id <> wo.invbook_definition_id
;
      