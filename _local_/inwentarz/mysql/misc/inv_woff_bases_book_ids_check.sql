SELECT wb.writeoff_basis_entry_id, wb.invbook_definition_id, wo.invbook_definition_id
FROM invbook_writeoff_bases wb
LEFT JOIN invbook_writeoffs wo ON wb.writeoff_id = wo.writeoff_id
WHERE wb.invbook_definition_id <> wo.invbook_definition_id
;
      