---
name: frappe-cli-orchestrator
description: Interacts with ERPNext and Frappe backends via frappe-cli, managing DocTypes, migration scripts, and database hooks.
---

# Frappe CLI Orchestrator Skill

## 1. Frappe CLI Execution
- Run bench and frappe-cli commands against target sites.
- Query DocTypes (Customer, Item, Sales Invoice, Payment Entry) to map schema changes.

## 2. ERP Data Synchronization
- Maps ShopSilo merchant orders and khata records directly to Frappe Sales Invoices and Journal Entries.
