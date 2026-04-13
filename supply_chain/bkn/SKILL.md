# Supply chain business knowledge network (BKN)

Modular BKN for the supply-chain demo: entities (customer, factory, supplier, …), transactional objects (orders, inventory, BOM, …), and relations between them.

## Layout

| Kind | Directory | Count |
|------|-----------|-------|
| Network root | [`network.bkn`](network.bkn) | 1 |
| Object types | [`object_types/`](object_types/) | 14 |
| Relation types | [`relation_types/`](relation_types/) | 17 |
| Concept groups | [`concept_groups/`](concept_groups/) | 3 |

## Object types (`object_types/`)

| Display name | File |
|--------------|------|
| 客户 | [object_types/customer.bkn](object_types/customer.bkn) |
| 工厂 | [object_types/factory.bkn](object_types/factory.bkn) |
| 供应商 | [object_types/supplier.bkn](object_types/supplier.bkn) |
| 物料 | [object_types/material.bkn](object_types/material.bkn) |
| 产品 | [object_types/product.bkn](object_types/product.bkn) |
| 仓库 | [object_types/warehouse.bkn](object_types/warehouse.bkn) |
| 产品BOM | [object_types/bom.bkn](object_types/bom.bkn) |
| 销售订单 | [object_types/sales_order.bkn](object_types/sales_order.bkn) |
| 库存清单 | [object_types/inventory.bkn](object_types/inventory.bkn) |
| 产品发货物流单 | [object_types/shipment.bkn](object_types/shipment.bkn) |
| 物料发货单 | [object_types/material_procurement.bkn](object_types/material_procurement.bkn) |
| 采购订单 | [object_types/purchase_order.bkn](object_types/purchase_order.bkn) |
| 产品生产单 | [object_types/production_order.bkn](object_types/production_order.bkn) |
| 物料领料单 | [object_types/material_requisition.bkn](object_types/material_requisition.bkn) |

## Relation types (`relation_types/`)

| Display name | File |
|--------------|------|
| 客户下销售订单 | [relation_types/customer_places_sales_order.bkn](relation_types/customer_places_sales_order.bkn) |
| 销售订单包含产品 | [relation_types/sales_order_contains_product.bkn](relation_types/sales_order_contains_product.bkn) |
| 产品关联产品BOM | [relation_types/product_links_bom.bkn](relation_types/product_links_bom.bkn) |
| 物料关联产品BOM | [relation_types/material_in_bom.bkn](relation_types/material_in_bom.bkn) |
| 物料关联库存清单 | [relation_types/material_in_inventory.bkn](relation_types/material_in_inventory.bkn) |
| 产品关联库存清单 | [relation_types/product_in_inventory.bkn](relation_types/product_in_inventory.bkn) |
| 库存清单关联仓库 | [relation_types/inventory_in_warehouse.bkn](relation_types/inventory_in_warehouse.bkn) |
| 仓库关联物料领料单 | [relation_types/warehouse_to_material_requisition.bkn](relation_types/warehouse_to_material_requisition.bkn) |
| 物料领料单关联工厂 | [relation_types/material_requisition_to_factory.bkn](relation_types/material_requisition_to_factory.bkn) |
| 工厂关联产品生产单 | [relation_types/factory_to_production_order.bkn](relation_types/factory_to_production_order.bkn) |
| 产品生产单关联产品 | [relation_types/production_order_for_product.bkn](relation_types/production_order_for_product.bkn) |
| 仓库提供产品发货物流单 | [relation_types/warehouse_provides_shipment.bkn](relation_types/warehouse_provides_shipment.bkn) |
| 产品发货物流单关联客户 | [relation_types/shipment_to_customer.bkn](relation_types/shipment_to_customer.bkn) |
| 采购订单包含物料 | [relation_types/purchase_order_contains_material.bkn](relation_types/purchase_order_contains_material.bkn) |
| 采购订单关联供应商 | [relation_types/purchase_order_from_supplier.bkn](relation_types/purchase_order_from_supplier.bkn) |
| 供应商提供物料发货单 | [relation_types/supplier_delivers_material_shipment.bkn](relation_types/supplier_delivers_material_shipment.bkn) |
| 物料发货单关联仓库 | [relation_types/material_shipment_to_warehouse.bkn](relation_types/material_shipment_to_warehouse.bkn) |

## Concept groups (`concept_groups/`)

| Name | File |
|------|------|
| 实体对象 | [concept_groups/entity_objects.bkn](concept_groups/entity_objects.bkn) |
| 事件对象 | [concept_groups/event_objects.bkn](concept_groups/event_objects.bkn) |
| 衍生对象 | [concept_groups/derived_objects.bkn](concept_groups/derived_objects.bkn) |

## Validate & push

```bash
kweaver bkn validate supply_chain/bkn
kweaver bkn push supply_chain/bkn
```

After push, bind each object type’s **Data Source** to the correct atomic data views in Studio (see [../README.md](../README.md)).
