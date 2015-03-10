ALTER TABLE `invbook_definitions`
ADD `cn_suffix` varchar(30) default ''
AFTER `cn_prefix`
;

ALTER TABLE `invbook_writeoffs`
ADD `notes_internal` mediumtext default ''
AFTER `notes`
;

ALTER TABLE `invbook_writeoffs`
ADD `current_status` varchar(30) NOT NULL default 'NA'
AFTER `reason`
;

ALTER TABLE `invbook_writeoff_bases`
CHANGE `writeoff_id` `writeoff_id` int(11) NOT NULL
;

ALTER TABLE `invbook_writeoff_bases`
CHANGE `invbook_item_id` `invbook_item_id` int(11) NOT NULL
;

ALTER TABLE `invbook_writeoff_bases`
CHANGE `seq_number` `seq_number` int(11) default NULL
;

ALTER TABLE `invbook_writeoff_bases`
ADD UNIQUE KEY `wob_seq_number_pseudo_unique_key` (`invbook_definition_id`,`seq_number`)
;

ALTER TABLE `invbook_writeoff_bases`
ADD UNIQUE KEY `wob_invbook_item_id_pseudo_unique_key` (`invbook_definition_id`,`invbook_item_id`)
;
