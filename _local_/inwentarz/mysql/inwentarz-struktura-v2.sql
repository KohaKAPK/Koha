--
-- Table structure for table `invbook_definitions`
--
CREATE TABLE IF NOT EXISTS `invbook_definitions` ( -- inventory book: definitions
   `invbook_definition_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `name` varchar(255) default '', -- full name/description of this inventory book (???)
   `name_abbrev` varchar(255) default '', -- abbreviated name (???)
   `bookcode` varchar(30) NOT NULL, -- unique inventory book symbol / book code; authorised value ???
   `type` varchar(10) NOT NULL, -- book type; coded value: I[tems]|W[riteoffs]|[A]ccessions
   `branchcode` varchar(10) NOT NULL default '', -- foreign key from the branches table
   `owned_by` int(11), -- foreign key (references borrowernumber) for the owner of this book (i.e, person which: added this definition/is able to set more granular permissions for staff members/..)
   `print_format` varchar(30) default '', -- coded/authorized value determinig in what format this book is being printed
   `display_format` varchar(30) default '', -- coded/authorized value determinig in how this book is being displayed/managed/etc.
   `numbering_format` varchar(30) default '', -- coded/authorized value determinig in how next nuber is being generated
   `date_start_of_numbering` date default NULL, -- numbering range start date (if this is partial inventory book)
   `notes` mediumtext default '', -- internal notes regarding this book, multiple values separated with '|' (???)
   `page_number_last` int(11) default 0, -- last page number used for this book in printed form
   -- `entry_nuber_last` internal counter for item|writeoff|accession number, i.e. last number generated as:
   -- invbook_items->inventory_number (for 'I' type)
   -- invbook_accessions->number_cnt (for 'A' type)
   -- invbook_writeoffs->writeoff_number (for 'W' type)
   `entry_number_last` int(11) default 0,
   `total_items` int(11) default 0, -- total items count (for entire book); can be entered manually to start numbering from some arbitrary value
   `total_cost` decimal(28,6) default 0, -- summary / total cost of accessioned and/or written off items for entire book (tax included)
   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched

   -- fields specific for book type 'I' (Inventory/Items)
   `cn_prefix` varchar(30) default '', -- call number prefix for items stored in this book (if any), eg.: 'II-'
   `default_location` varchar(80) default NULL, -- authorized value for the default shelving location for items stored in this book (MARC21 952 $c)

   -- fields specific for book type 'W' (Writeoffs)
   `writeoff_basis_seq_number_last` int(11) default 0, -- internal counter for writeoff basis, i.e. last number used as `seq_number` in invbook_writeoff_bases
   `writeoff_parent_invbook_defn_id` int(11), -- parent/main inventory book definition id this writoff book definition is associated with; FIXME (FK)

   -- fields specific for book types 'A' (Accessions re/ number_*) and 'W' (Writeoffs re/ base_document_number_*)
   `number_prefix` varchar(30), -- e.g. "WM-N-Z-", "2014/", "/YYYY" (???)
   `number_suffix` varchar(30), -- e.g. "/YYYY" (???)

   PRIMARY KEY (`invbook_definition_id`),
   UNIQUE KEY `iv_defs_pseudo_unique_key` (`bookcode`,`type`),
   KEY `branchcode` (`branchcode`),
   KEY `owned_by` (`owned_by`),

   CONSTRAINT `invbook_definitions_ibfk_1` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_definitions_ibfk_2` FOREIGN KEY (`owned_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `invbook_permissions`
--
CREATE TABLE IF NOT EXISTS `invbook_permissions` ( -- inventory book: user permissions / access restriction
   `invbook_permission_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `invbook_definition_id` int(11) NOT NULL, -- foreign key: inventory book definition id
   `branchcode` varchar(10) NOT NULL default '', -- foreign key from the branches table
   `userid` int(11) NOT NULL, -- foreign key (references borrowernumber) for the staff user record
   `permission` varchar(30) NOT NULL default '', -- coded value[s] determinig actual permissions/restrictions given to the user, eg. I|E|S|U
   `description` varchar(255) default '', -- optional description of this entry

   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched

   PRIMARY KEY (`invbook_permission_id`),
   KEY `invbook_definition_id` (`invbook_definition_id`),
   KEY `userid` (`userid`),
   KEY `branchcode` (`branchcode`),
   KEY `permission` (`permission`),
   CONSTRAINT `invbook_permissions_ibfk_1` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_permissions_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
   CONSTRAINT `invbook_permissions_ibfk_3` FOREIGN KEY (`invbook_definition_id`) REFERENCES `invbook_definitions` (`invbook_definition_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `invbook_accessions`
--
CREATE TABLE IF NOT EXISTS `invbook_accessions` ( -- inventory book: accessions register
   `accession_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `invbook_definition_id` int(11) NOT NULL, -- foreign key: book definition id (type 'A')
   `number_prefix` varchar(30), -- e.g. "WM-N-Z-", "2014/", authorized value (???)
   `number_cnt` int(11), -- e.g. "123", auto-generated (???)
   `number_suffix` varchar(30), -- e.g. "/2014",  authorized / auto generated value (???)
   `total_cost` decimal(28,6) NOT NULL default 0, -- total amount paid for the accessioned items (actual cost, including taxes); calculated from items, or entered manually
   `invoice_document_nr` varchar(255) NOT NULL, -- invoice / document number (from acquisition module, or entered manually); CHECKME: 1|1+ ???
   `invoice_id` int(11), -- ??? foreign key, references aqinvoices->invoiceid; if NULL, invoice_document_nr is managed manually
   `vendor_name` mediumtext NOT NULL, -- vendor name (copied from aqbooksellers->name, and/or entered manually ??)
   `vendor_id` int(11), -- ??? foreign key, references aqbooksellers->id
   `notes` mediumtext default '', -- notes, multiple values separated with '|'
   `notes_import` mediumtext default '', -- internal notes regarding importing this entry from another database (...)

   `date_accessioned` date NOT NULL, -- accession date (YYYY-MM-DD)
   `date_entered` date NOT NULL, -- when this entry was (manually ?) added (YYYY-MM-DD)
   `cost_managed_manually` tinyint(4) default 0, -- total_cost was manually entered; do not [re]calculate automatically (1 for yes, 0 for no)
   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched
   `created_by` int(11), -- foreign key (references borrowernumber) for the creator of this record
   `modified_by` int(11), -- foreign key (references borrowernumber) for the staff user who last modified this record

   PRIMARY KEY (`accession_id`),
   UNIQUE KEY `iv_acc_pseudo_unique_key` (`number_prefix`,`number_cnt`,`number_suffix`),
   KEY `invbook_definition_id` (`invbook_definition_id`),
   KEY `invoice_document_nr` (`invoice_document_nr`),
   KEY `invoice_id` (`invoice_id`),
   KEY `vendor_id` (`vendor_id`),
   KEY `created_by` (`created_by`),
   KEY `modified_by` (`modified_by`),

   CONSTRAINT `invbook_accessions_ibfk_1` FOREIGN KEY (`invoice_id`) REFERENCES `aqinvoices` (`invoiceid`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_accessions_ibfk_2` FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_accessions_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_accessions_ibfk_4` FOREIGN KEY (`modified_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_accessions_ibfk_5` FOREIGN KEY (`invbook_definition_id`) REFERENCES `invbook_definitions` (`invbook_definition_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `invbook_writeoffs`
--
CREATE TABLE IF NOT EXISTS `invbook_writeoffs` ( -- inventory book: writeoffs register
   `writeoff_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `invbook_definition_id` int(11) NOT NULL, -- foreign key: book definition id (type "W")
   `writeoff_number` int(11) NOT NULL, -- number of this register entry (writeoff number)
   -- following fields are for writeoff bases/accompanying documents numbering !!!
   `base_document_number_prefix` varchar(30), -- e.g. "2014/", authorized value (???)
   `base_document_number_cnt` int(11), -- e.g. "123", auto-generated (???)
   `base_document_number_suffix` varchar(30), -- e.g. "/YYYY",  authorized / auto generated value (???)
   `base_document_description` mediumtext default '', -- common document name/description we want to appear on the writeoff basis document
   `notes` mediumtext default '', -- notes, multiple values separated with '|'
   `notes_import` mediumtext default '', -- internal notes regarding importing this entry from another database (...)

   `total_cost` decimal(28,6) NOT NULL default 0, -- total amount for the written-off items; calculated from accompanying document item list, or entered manually
   `unit_count` int(11) NOT NULL default 0, -- total count of the written-off items; calculated from item list, or entered manually
   `reason` varchar(255) NOT NULL, -- coded / authorized value (???), reason why items were written off (or should this field rather be more granular / in invbook_writeoff_bases ???)
   `date_writeoff` date NOT NULL, -- when this write-off was added to the registry (YYYY-MM-DD)
   `date_document` date, -- what date we want to appear on writeoff basis document (YYYY-MM-DD) (CHECKME: redundant ??)
   `date_printed` date, -- date this entry was printed (YYYY-MM-DD)
   `cost_managed_manually` tinyint(4) default 0, -- total_cost was manually entered; do not [re]calculate automatically (1 for yes, 0 for no)
   `count_managed_manually` tinyint(4) default 0, -- unit_count was manually entered; do not [re]calculate automatically (1 for yes, 0 for no)
   `paging_number` int(11) default NULL, -- page number this entry was printed on
   `paging_total_cost_moved_from` decimal(28,6), -- FIXME
   `paging_total_cost_moved_to` decimal(28,6),

   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched
   `created_by` int(11), -- foreign key (references borrowernumber) for the creator of this record
   `modified_by` int(11), -- foreign key (references borrowernumber) for the staff user who last modified this record

   PRIMARY KEY (`writeoff_id`),
   UNIQUE KEY `iv_woffwn_pseudo_unique_key` (`invbook_definition_id`,`writeoff_number`),
   UNIQUE KEY `iv_woffdb_pseudo_unique_key` (`invbook_definition_id`,`base_document_number_prefix`,`base_document_number_cnt`,`base_document_number_suffix`),
   KEY `invbook_definition_id` (`invbook_definition_id`),
   KEY `created_by` (`created_by`),
   KEY `modified_by` (`modified_by`),

   CONSTRAINT `invbook_writeoffs_ibfk_1` FOREIGN KEY (`invbook_definition_id`) REFERENCES `invbook_definitions` (`invbook_definition_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_writeoffs_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_writeoffs_ibfk_3` FOREIGN KEY (`modified_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `invbook_items`
--
CREATE TABLE IF NOT EXISTS `invbook_items` ( -- inventory book: item register
   `invbook_item_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `invbook_definition_id` int(11) NOT NULL, -- foreign key: book definition id (type "I")
   `inventory_number` int(11) NOT NULL, -- number of this register entry (inventory number)
   `accession_id` int(11) NOT NULL, -- foreign key: accession record id

   `biblionumber` int(11) default NULL, -- foreign key: bibliographic record id
   `itemnumber` int(11) default NULL, -- foreign key: item record id
   `callnumber` varchar(255) NOT NULL, -- call number for this item (MARC21 952 $o)

   `title` mediumtext default '', -- MARC21 245 $a $b $n $p (???)
   `author` mediumtext default '', -- MARC21 $c ???)
   `publication_place` varchar(255) default '',
   `publication_date` varchar(255) default '',
   `notes` mediumtext default '', -- notes (printed), multiple values separated with '|'
   `notes_internal` mediumtext default '', -- auxillary / general / internal notes (not printed), separated with '|'
   `notes_import` mediumtext default '', -- internal notes regarding importing this entry from another database (...)
   `st_class_1` varchar(255) default '', -- statistical class #1: one or more language codes; multiple values separated with ' ' (???)
   `st_class_2` varchar(255) default '', -- statistical class #2: auth. value[s] (???) for classification / division (CHECKME: 1|1+ ???)

   `unitprice` decimal(28,6) NOT NULL default 0, -- amount paid for this item/ actual cost (including taxes)
   `location` varchar(80) default NULL, -- authorized value for the shelving location for this item (MARC21 952 $c) - if any
   `acquisition_mode` varchar(10) NOT NULL default 'K', -- coded value (K|W|D|I) determinig acquisition mode (item was: purchased / exchanged / it's a gift / other)

   `update_history_log` mediumtext default '', -- where all changes of this record are being logged
   `paging_number` int(11) default NULL, -- page number this item was printed on
   `paging_item_count_moved_from` int(11), -- FIXME
   `paging_total_cost_moved_from` decimal(28,6),
   `paging_item_count_moved_to` int(11),
   `paging_total_cost_moved_to` decimal(28,6),

   `writeoff_id` int(11), -- foreign key: references writeoff_id from invbook_writeoffs; FIXME (FK)
   `writeoff_basis_entry_id` int(11), -- foreign key: references writeoff_basis_entry_id from invbook_writeoff_bases; FIXME (FK)

   `date_added` date NOT NULL, -- date this entry was added to inventory (YYYY-MM-DD)
   `date_printed` date, -- date this entry was printed (YYYY-MM-DD), also date when locally stored bibliografic & price fields etc. were last updated
   `date_incorporated` date, -- date this item was incorporated into stock / transfered to designated permanent location
   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched
   `created_by` int(11), -- foreign key (references borrowernumber) for the creator of this record
   `modified_by` int(11), -- foreign key (references borrowernumber) for the staff user who last modified this record

   PRIMARY KEY (`invbook_item_id`),
   UNIQUE KEY `iv_nr_pseudo_unique_key` (`invbook_definition_id`,`inventory_number`),
   KEY `invbook_definition_id` (`invbook_definition_id`),
   KEY `accession_id` (`accession_id`),
   KEY `inventory_number` (`inventory_number`),
   KEY `biblionumber` (`biblionumber`),
   KEY `itemnumber` (`itemnumber`),
   KEY `callnumber` (`callnumber`),
   -- KEY `title` (`title`),
   -- KEY `author` (`author`),
   KEY `location` (`location`),
   KEY `unitprice` (`unitprice`),
   -- KEY `update_history_log` (`update_history_log`),
   KEY `paging_number` (`paging_number`),
   KEY `st_class_1` (`st_class_1`),
   KEY `st_class_2` (`st_class_2`),
   KEY `created_by` (`created_by`),
   KEY `modified_by` (`modified_by`),

   CONSTRAINT `invbook_items_ibfk_1` FOREIGN KEY (`invbook_definition_id`) REFERENCES `invbook_definitions` (`invbook_definition_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_items_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_items_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_items_ibfk_4` FOREIGN KEY (`accession_id`) REFERENCES `invbook_accessions` (`accession_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_items_ibfk_5` FOREIGN KEY (`created_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_items_ibfk_6` FOREIGN KEY (`modified_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `invbook_writeoff_bases`
--
CREATE TABLE IF NOT EXISTS `invbook_writeoff_bases` ( -- inventory book: writeoff bases / accompanying documents individual item entries
   `writeoff_basis_entry_id` int(11) NOT NULL AUTO_INCREMENT, -- unique id for the record
   `invbook_definition_id` int(11) NOT NULL, -- foreign key: book definition id (type 'W')
   `writeoff_id` int(11), -- foreign key: references writeoff_id from invbook_writeoffs
   `invbook_item_id` int(11), -- references invbook_items (non-foreign key to avoid circular reference)

   `seq_number` int(11) NOT NULL, -- sequential number of this entry/item as appearing on printed form of writeoffs bases / accompanying documents
   `notes` mediumtext default '', -- item specific notes (printed), multiple values separated with '|'
   `notes_internal` mediumtext default '', -- auxillary / general / internal notes (not printed), separated with '|'
   `notes_import` mediumtext default '', -- internal notes regarding importing this entry from another database (...)

   `paging_number` int(11) default NULL, -- (base; numbering scheme: 1..N) document page number this item was printed on
   `paging_total_cost_moved_from` decimal(28,6), -- ???
   `paging_total_cost_moved_to` decimal(28,6), -- ???

   `date_added` date NOT NULL, -- date this item was added to writeoff base / acompanying document (YYYY-MM-DD)
   `date_printed` date, -- date this entry was printed (YYYY-MM-DD)
   `timestamp_updated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched
   `created_by` int(11), -- foreign key (references borrowernumber) for the creator of this record
   `modified_by` int(11), -- foreign key (references borrowernumber) for the staff user who last modified this record

   PRIMARY KEY (`writeoff_basis_entry_id`),
   KEY `invbook_definition_id` (`invbook_definition_id`),
   KEY `writeoff_id` (`writeoff_id`),
   KEY `invbook_item_id` (`invbook_item_id`),
   KEY `seq_number` (`seq_number`),
   KEY `paging_number` (`paging_number`),
   KEY `created_by` (`created_by`),
   KEY `modified_by` (`modified_by`),

   CONSTRAINT `invbook_writeoff_bases_ibfk_1` FOREIGN KEY (`invbook_definition_id`) REFERENCES `invbook_definitions` (`invbook_definition_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_writeoff_bases_ibfk_2` FOREIGN KEY (`writeoff_id`) REFERENCES `invbook_writeoffs` (`writeoff_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
   CONSTRAINT `invbook_writeoff_bases_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE,
   CONSTRAINT `invbook_writeoff_bases_ibfk_4` FOREIGN KEY (`modified_by`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
