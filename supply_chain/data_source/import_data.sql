-- Simple CSV import for supply_chain demo_data
-- Run from repository root:
--   mysql --local-infile=1 -u USER -p DATABASE < supply_chain/data_source/import_data.sql
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- bom_event <= bom_event_202604141453.csv
DROP TABLE IF EXISTS `bom_event`;
CREATE TABLE `bom_event` (`bom_id` TEXT, `bom_version` TEXT, `parent_type` TEXT, `parent_id` TEXT, `parent_code` TEXT, `child_type` TEXT, `child_id` TEXT, `child_code` TEXT, `child_name` TEXT, `relationship_type` TEXT, `quantity` TEXT, `unit` TEXT, `child_quantity` TEXT, `child_unit` TEXT, `base_quantity` TEXT, `effective_date` TEXT, `expiry_date` TEXT, `bom_category` TEXT, `assembly_set` TEXT, `issue_method` TEXT, `scrap_rate` TEXT, `created_by` TEXT, `created_date` TEXT, `status` TEXT, `alt_priority` TEXT, `alt_group_no` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/bom_event_202604141453.csv'
INTO TABLE `bom_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`bom_id`, `bom_version`, `parent_type`, `parent_id`, `parent_code`, `child_type`, `child_id`, `child_code`, `child_name`, `relationship_type`, `quantity`, `unit`, `child_quantity`, `child_unit`, `base_quantity`, `effective_date`, `expiry_date`, `bom_category`, `assembly_set`, `issue_method`, `scrap_rate`, `created_by`, `created_date`, `status`, `alt_priority`, `alt_group_no`);

-- customer_entity <= customer_entity_202604141453.csv
DROP TABLE IF EXISTS `customer_entity`;
CREATE TABLE `customer_entity` (`customer_id` TEXT, `customer_code` TEXT, `customer_name` TEXT, `customer_level` TEXT, `primary_industry` TEXT, `secondary_industry` TEXT, `company_size` TEXT, `established_year` TEXT, `annual_revenue` TEXT, `city` TEXT, `province` TEXT, `contact_person` TEXT, `contact_phone` TEXT, `contact_email` TEXT, `is_named_customer` TEXT, `has_contract` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/customer_entity_202604141453.csv'
INTO TABLE `customer_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`customer_id`, `customer_code`, `customer_name`, `customer_level`, `primary_industry`, `secondary_industry`, `company_size`, `established_year`, `annual_revenue`, `city`, `province`, `contact_person`, `contact_phone`, `contact_email`, `is_named_customer`, `has_contract`, `created_date`, `status`);

-- factory_entity <= factory_entity_202604141453.csv
DROP TABLE IF EXISTS `factory_entity`;
CREATE TABLE `factory_entity` (`factory_id` TEXT, `factory_code` TEXT, `factory_name` TEXT, `city` TEXT, `province` TEXT, `country` TEXT, `production_lines` TEXT, `total_capacity` TEXT, `established_year` TEXT, `area_sqm` TEXT, `employee_count` TEXT, `manager` TEXT, `contact_phone` TEXT, `contact_email` TEXT, `certification` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/factory_entity_202604141453.csv'
INTO TABLE `factory_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`factory_id`, `factory_code`, `factory_name`, `city`, `province`, `country`, `production_lines`, `total_capacity`, `established_year`, `area_sqm`, `employee_count`, `manager`, `contact_phone`, `contact_email`, `certification`, `created_date`, `status`);

-- forecast_event <= forecast_event_202604141454.csv
DROP TABLE IF EXISTS `forecast_event`;
CREATE TABLE `forecast_event` (`forecast_id` TEXT, `billno` TEXT, `material_number` TEXT, `material_name` TEXT, `startdate` TEXT, `enddate` TEXT, `qty` TEXT, `forecast_month` TEXT, `created_date` TEXT, `creator` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/forecast_event_202604141454.csv'
INTO TABLE `forecast_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`forecast_id`, `billno`, `material_number`, `material_name`, `startdate`, `enddate`, `qty`, `forecast_month`, `created_date`, `creator`, `status`);

-- inventory_event_update <= inventory_event_update_202604141454.csv
DROP TABLE IF EXISTS `inventory_event_update`;
CREATE TABLE `inventory_event_update` (`inventory_id` TEXT, `snapshot_month` TEXT, `item_id` TEXT, `item_code` TEXT, `warehouse_id` TEXT, `batch_number` TEXT, `quantity` TEXT, `reserved_inventory_qty` TEXT, `earliest_storage_date` TEXT, `max_storage_age` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/inventory_event_update_202604141454.csv'
INTO TABLE `inventory_event_update`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`inventory_id`, `snapshot_month`, `item_id`, `item_code`, `warehouse_id`, `batch_number`, `quantity`, `reserved_inventory_qty`, `earliest_storage_date`, `max_storage_age`, `created_date`, `status`);

-- material_entity <= material_entity_202604141454.csv
DROP TABLE IF EXISTS `material_entity`;
CREATE TABLE `material_entity` (`material_id` TEXT, `material_code` TEXT, `material_name` TEXT, `material_type` TEXT, `unit` TEXT, `is_virtual` TEXT, `is_assembly` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/material_entity_202604141454.csv'
INTO TABLE `material_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`material_id`, `material_code`, `material_name`, `material_type`, `unit`, `is_virtual`, `is_assembly`, `created_date`, `status`);

-- material_procurement_event <= material_procurement_event_202604141454.csv
DROP TABLE IF EXISTS `material_procurement_event`;
CREATE TABLE `material_procurement_event` (`procurement_id` TEXT, `procurement_number` TEXT, `procurement_date` TEXT, `supplier_id` TEXT, `supplier_code` TEXT, `supplier_name` TEXT, `material_id` TEXT, `material_code` TEXT, `material_name` TEXT, `warehouse_id` TEXT, `warehouse_name` TEXT, `quantity` TEXT, `unit_price` TEXT, `total_amount` TEXT, `currency` TEXT, `tax_rate` TEXT, `payment_terms` TEXT, `logistics_provider` TEXT, `tracking_number` TEXT, `ship_date` TEXT, `estimated_delivery_date` TEXT, `actual_delivery_date` TEXT, `inspection_status` TEXT, `notes` TEXT, `created_date` TEXT, `status` TEXT, `po_number` TEXT, `delivery_batch` TEXT, `total_batches` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/material_procurement_event_202604141454.csv'
INTO TABLE `material_procurement_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`procurement_id`, `procurement_number`, `procurement_date`, `supplier_id`, `supplier_code`, `supplier_name`, `material_id`, `material_code`, `material_name`, `warehouse_id`, `warehouse_name`, `quantity`, `unit_price`, `total_amount`, `currency`, `tax_rate`, `payment_terms`, `logistics_provider`, `tracking_number`, `ship_date`, `estimated_delivery_date`, `actual_delivery_date`, `inspection_status`, `notes`, `created_date`, `status`, `po_number`, `delivery_batch`, `total_batches`);

-- material_requisition_event <= material_requisition_event_202604141455.csv
DROP TABLE IF EXISTS `material_requisition_event`;
CREATE TABLE `material_requisition_event` (`material_requisition_id` TEXT, `requisition_number` TEXT, `requisition_type` TEXT, `material_id` TEXT, `material_code` TEXT, `material_name` TEXT, `warehouse_id` TEXT, `factory_id` TEXT, `requested_quantity` TEXT, `issued_quantity` TEXT, `unit` TEXT, `requisition_date` TEXT, `issue_date` TEXT, `production_order_number` TEXT, `purpose` TEXT, `status` TEXT, `created_date` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/material_requisition_event_202604141455.csv'
INTO TABLE `material_requisition_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`material_requisition_id`, `requisition_number`, `requisition_type`, `material_id`, `material_code`, `material_name`, `warehouse_id`, `factory_id`, `requested_quantity`, `issued_quantity`, `unit`, `requisition_date`, `issue_date`, `production_order_number`, `purpose`, `status`, `created_date`);

-- mrp_plan_order_event_update <= mrp_plan_order_event_update_202604141456.csv
DROP TABLE IF EXISTS `mrp_plan_order_event_update`;
CREATE TABLE `mrp_plan_order_event_update` (`mrp_id` TEXT, `billno` TEXT, `materialplanid_number` TEXT, `materialplanid_name` TEXT, `materialattr_title` TEXT, `adviseorderqty` TEXT, `bizorderqty` TEXT, `advisestartdate` TEXT, `adviseenddate` TEXT, `startdate` TEXT, `enddate` TEXT, `orderdate` TEXT, `availabledate` TEXT, `closestatus_title` TEXT, `dropbilltype_name` TEXT, `droptime` TEXT, `rootdemandbillno` TEXT, `planoperatenum` TEXT, `createtime` TEXT, `creator_name` TEXT, `status` TEXT, `closestatus_reason` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/mrp_plan_order_event_update_202604141456.csv'
INTO TABLE `mrp_plan_order_event_update`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`mrp_id`, `billno`, `materialplanid_number`, `materialplanid_name`, `materialattr_title`, `adviseorderqty`, `bizorderqty`, `advisestartdate`, `adviseenddate`, `startdate`, `enddate`, `orderdate`, `availabledate`, `closestatus_title`, `dropbilltype_name`, `droptime`, `rootdemandbillno`, `planoperatenum`, `createtime`, `creator_name`, `status`, `closestatus_reason`);

-- product_entity <= product_entity_202604141456.csv
DROP TABLE IF EXISTS `product_entity`;
CREATE TABLE `product_entity` (`product_id` TEXT, `product_code` TEXT, `product_name` TEXT, `product_type` TEXT, `main_unit` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/product_entity_202604141456.csv'
INTO TABLE `product_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`product_id`, `product_code`, `product_name`, `product_type`, `main_unit`, `created_date`, `status`);

-- production_order_event <= production_order_event_202604141456.csv
DROP TABLE IF EXISTS `production_order_event`;
CREATE TABLE `production_order_event` (`production_order_id` TEXT, `production_order_number` TEXT, `output_type` TEXT, `output_id` TEXT, `output_code` TEXT, `output_name` TEXT, `production_quantity` TEXT, `factory_id` TEXT, `factory_name` TEXT, `production_line` TEXT, `process_sequence` TEXT, `planned_start_date` TEXT, `planned_finish_date` TEXT, `work_order_status` TEXT, `priority` TEXT, `created_date` TEXT, `status` TEXT, `sourcebillnumber` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/production_order_event_202604141456.csv'
INTO TABLE `production_order_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`production_order_id`, `production_order_number`, `output_type`, `output_id`, `output_code`, `output_name`, `production_quantity`, `factory_id`, `factory_name`, `production_line`, `process_sequence`, `planned_start_date`, `planned_finish_date`, `work_order_status`, `priority`, `created_date`, `status`, `sourcebillnumber`);

-- purchase_order_event <= purchase_order_event_202604141456.csv
DROP TABLE IF EXISTS `purchase_order_event`;
CREATE TABLE `purchase_order_event` (`purchase_order_id` TEXT, `purchase_order_number` TEXT, `document_date` TEXT, `supplier_id` TEXT, `supplier_name` TEXT, `material_id` TEXT, `material_code` TEXT, `material_name` TEXT, `purchase_quantity` TEXT, `unit_price_tax` TEXT, `tax_rate` TEXT, `document_status` TEXT, `required_date` TEXT, `planned_arrival_date` TEXT, `accumulated_arrival_tax` TEXT, `accumulated_storage_tax` TEXT, `payment_terms` TEXT, `buyer` TEXT, `created_date` TEXT, `status` TEXT, `srcbillid` TEXT, `srcbillentryid` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/purchase_order_event_202604141456.csv'
INTO TABLE `purchase_order_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`purchase_order_id`, `purchase_order_number`, `document_date`, `supplier_id`, `supplier_name`, `material_id`, `material_code`, `material_name`, `purchase_quantity`, `unit_price_tax`, `tax_rate`, `document_status`, `required_date`, `planned_arrival_date`, `accumulated_arrival_tax`, `accumulated_storage_tax`, `payment_terms`, `buyer`, `created_date`, `status`, `srcbillid`, `srcbillentryid`);

-- purchase_requisition_event <= purchase_requisition_event_202604141457.csv
DROP TABLE IF EXISTS `purchase_requisition_event`;
CREATE TABLE `purchase_requisition_event` (`pr_id` TEXT, `billno` TEXT, `entry_id` TEXT, `material_number` TEXT, `material_name` TEXT, `material_type` TEXT, `qty` TEXT, `unit` TEXT, `biztime` TEXT, `plant` TEXT, `buyer` TEXT, `srcbillid` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/purchase_requisition_event_202604141457.csv'
INTO TABLE `purchase_requisition_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`pr_id`, `billno`, `entry_id`, `material_number`, `material_name`, `material_type`, `qty`, `unit`, `biztime`, `plant`, `buyer`, `srcbillid`, `created_date`, `status`);

-- sales_order_event <= sales_order_event_202604141457.csv
DROP TABLE IF EXISTS `sales_order_event`;
CREATE TABLE `sales_order_event` (`sales_order_id` TEXT, `sales_order_number` TEXT, `document_date` TEXT, `customer_id` TEXT, `customer_name` TEXT, `line_number` TEXT, `product_id` TEXT, `product_code` TEXT, `product_name` TEXT, `quantity` TEXT, `unit` TEXT, `standard_price` TEXT, `discount_rate` TEXT, `actual_price` TEXT, `subtotal_amount` TEXT, `order_status` TEXT, `document_status` TEXT, `transaction_type` TEXT, `sales_department` TEXT, `salesperson` TEXT, `planned_delivery_date` TEXT, `is_urgent` TEXT, `contract_number` TEXT, `project_name` TEXT, `end_customer` TEXT, `quotation_number` TEXT, `notes` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/sales_order_event_202604141457.csv'
INTO TABLE `sales_order_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`sales_order_id`, `sales_order_number`, `document_date`, `customer_id`, `customer_name`, `line_number`, `product_id`, `product_code`, `product_name`, `quantity`, `unit`, `standard_price`, `discount_rate`, `actual_price`, `subtotal_amount`, `order_status`, `document_status`, `transaction_type`, `sales_department`, `salesperson`, `planned_delivery_date`, `is_urgent`, `contract_number`, `project_name`, `end_customer`, `quotation_number`, `notes`, `created_date`, `status`);

-- shipment_event <= shipment_event_202604141457.csv
DROP TABLE IF EXISTS `shipment_event`;
CREATE TABLE `shipment_event` (`shipment_id` TEXT, `shipment_number` TEXT, `shipment_date` TEXT, `warehouse_id` TEXT, `warehouse_name` TEXT, `quantity` TEXT, `consignee` TEXT, `consignee_phone` TEXT, `delivery_address` TEXT, `logistics_provider` TEXT, `tracking_number` TEXT, `actual_delivery_date` TEXT, `delivery_status` TEXT, `sales_order_number` TEXT, `notes` TEXT, `created_date` TEXT, `status` TEXT, `customer_id` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/shipment_event_202604141457.csv'
INTO TABLE `shipment_event`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`shipment_id`, `shipment_number`, `shipment_date`, `warehouse_id`, `warehouse_name`, `quantity`, `consignee`, `consignee_phone`, `delivery_address`, `logistics_provider`, `tracking_number`, `actual_delivery_date`, `delivery_status`, `sales_order_number`, `notes`, `created_date`, `status`, `customer_id`);

-- supplier_entity <= supplier_entity_202604141457.csv
DROP TABLE IF EXISTS `supplier_entity`;
CREATE TABLE `supplier_entity` (`supplier_id` TEXT, `supplier_code` TEXT, `supplier_name` TEXT, `supplier_short_name` TEXT, `supplier_category` TEXT, `supplier_tier` TEXT, `primary_contact` TEXT, `contact_phone` TEXT, `contact_email` TEXT, `registered_address` TEXT, `country` TEXT, `city` TEXT, `settlement_currency` TEXT, `default_tax_rate` TEXT, `payment_terms` TEXT, `lead_time_avg` TEXT, `risk_level` TEXT, `is_active` TEXT, `established_year` TEXT, `annual_capacity` TEXT, `created_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/supplier_entity_202604141457.csv'
INTO TABLE `supplier_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`supplier_id`, `supplier_code`, `supplier_name`, `supplier_short_name`, `supplier_category`, `supplier_tier`, `primary_contact`, `contact_phone`, `contact_email`, `registered_address`, `country`, `city`, `settlement_currency`, `default_tax_rate`, `payment_terms`, `lead_time_avg`, `risk_level`, `is_active`, `established_year`, `annual_capacity`, `created_date`, `status`);

-- warehouse_entity <= warehouse_entity_202604141457.csv
DROP TABLE IF EXISTS `warehouse_entity`;
CREATE TABLE `warehouse_entity` (`warehouse_id` TEXT, `warehouse_code` TEXT, `warehouse_name` TEXT, `warehouse_type` TEXT, `address` TEXT, `city` TEXT, `province` TEXT, `country` TEXT, `postal_code` TEXT, `latitude` TEXT, `longitude` TEXT, `total_area_sqm` TEXT, `storage_area_sqm` TEXT, `warehouse_height` TEXT, `storage_capacity_cbm` TEXT, `pallet_positions` TEXT, `temperature_control` TEXT, `temperature_range` TEXT, `humidity_control` TEXT, `humidity_range` TEXT, `has_cold_storage` TEXT, `fire_protection_level` TEXT, `security_system` TEXT, `has_wms` TEXT, `wms_system` TEXT, `automation_level` TEXT, `has_agv` TEXT, `agv_count` TEXT, `has_conveyor` TEXT, `has_sorting_system` TEXT, `has_rfid` TEXT, `established_year` TEXT, `operation_hours` TEXT, `max_daily_throughput` TEXT, `throughput_unit` TEXT, `manager_name` TEXT, `manager_phone` TEXT, `manager_email` TEXT, `employee_count` TEXT, `certifications` TEXT, `quality_standards` TEXT, `created_date` TEXT, `last_inspection_date` TEXT, `status` TEXT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
LOAD DATA LOCAL INFILE 'supply_chain/data_source/demo_data/warehouse_entity_202604141457.csv'
INTO TABLE `warehouse_entity`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`warehouse_id`, `warehouse_code`, `warehouse_name`, `warehouse_type`, `address`, `city`, `province`, `country`, `postal_code`, `latitude`, `longitude`, `total_area_sqm`, `storage_area_sqm`, `warehouse_height`, `storage_capacity_cbm`, `pallet_positions`, `temperature_control`, `temperature_range`, `humidity_control`, `humidity_range`, `has_cold_storage`, `fire_protection_level`, `security_system`, `has_wms`, `wms_system`, `automation_level`, `has_agv`, `agv_count`, `has_conveyor`, `has_sorting_system`, `has_rfid`, `established_year`, `operation_hours`, `max_daily_throughput`, `throughput_unit`, `manager_name`, `manager_phone`, `manager_email`, `employee_count`, `certifications`, `quality_standards`, `created_date`, `last_inspection_date`, `status`);

SET FOREIGN_KEY_CHECKS = 1;
