# 💰 GR Delivery Costs Analysis Report

## Overview

This ABAP report analyzes the total landed cost of purchased materials by combining goods receipt (GR) values with all associated delivery charges from vendor invoices. It provides a complete view of procurement costs including freight, customs, insurance, and other conditions in both local and document currencies.

## Business Purpose

**Problems Solved:**
- No standard SAP report shows GR values with associated delivery costs
- Manual calculation of total landed costs is error-prone
- Difficulty tracking various charges (freight, customs, insurance) per PO
- Invoice verification requires multiple transaction checks
- No consolidated view for import cost analysis

**Business Value:**
- Accurate total landed cost for pricing decisions
- Complete audit trail linking GRs to invoice charges
- Support for vendor cost comparisons beyond material price
- Import budget tracking and analysis
- Streamlined invoice verification process

## Key Features

- **Dual Line Display**: GR values (base cost) + Condition records (additional charges)
- **Multi-Currency Support**: Simultaneous local and document currency display
- **Flexible Conditions**: Maps any pricing schema condition types
- **Invoice Linkage**: Shows vendor invoice reference numbers
- **Hierarchical ALV**: PO → Currency → Condition Type → Item structure
- **Smart Aggregations**: Automatic subtotals at each level
- **Incoterms Visibility**: Shows delivery terms for cost analysis
- **Payment Terms**: Includes payment conditions for cash flow planning

## ⚠️ CRITICAL: Company-Specific Customizations Required

### 1. **Local Currency** (Lines ~178 and ~258)
```abap
ls_final-waers_local = 'EGP'.  " ← CHANGE TO YOUR LOCAL CURRENCY
```

### 2. **Condition Type Mapping** (Form `map_condition_name` starting line ~295)
```abap
FORM map_condition_name...
  CASE iv_kschl.
    WHEN 'ZADS'.  cv_text = 'مصاريف اضافية'.  " ← REPLACE WITH YOUR CONDITIONS
    WHEN 'ZBNK'.  cv_text = 'مصاريف بنكية'.   " ← AND YOUR DESCRIPTIONS
    " ... DELETE ALL AND ADD YOUR OWN
```

### 3. **Language Settings** (Lines ~188, ~339, ~347)
```abap
WHERE spras = @sy-langu.  " Some hardcoded as 'EN' ← STANDARDIZE
```

### 4. **Company Code** (Optional - if implementing dynamic currency)
```abap
" Add constant at report start:
CONSTANTS: gc_bukrs TYPE bukrs VALUE '1000'.  " ← YOUR COMPANY CODE
```

### 5. **Movement Type** (Line ~90)
```abap
AND bewtp = 'Q'  " ← Verify Q is used for goods receipts in your system
```

## Installation

1. **Open SE38** (ABAP Editor)

2. **Create New Program**
   - Program name: `ZMM_GR_DELIVERY_COSTS_NEW`
   - Type: `Executable program`
   - Status: `Test program`

3. **Copy Source Code**
   - Copy the entire ABAP code
   - Paste into the editor

4. **Make Required Customizations**
   - Update currency (2 locations)
   - Replace ALL condition types with yours
   - Standardize language settings
   - Save (Ctrl+S)

5. **Check Syntax** (Ctrl+F2)
   - Fix any errors before proceeding

6. **Activate** (Ctrl+F3)
   - Program is now ready to use

7. **Create Transaction Code** (Optional)
   - SE93 → New
   - Transaction code: `ZMM_GR_COSTS`
   - Select "Program and selection screen"
   - Program: `ZMM_GR_DELIVERY_COSTS_NEW`

## Usage

### Running the Report

1. **Execute Transaction** `ZMM_GR_COSTS` or run via SE38

2. **Selection Screen Parameters:**
   - **Purchase Order**: Optional - leave blank for all POs
   - **Posting Date**: Required - date range for analysis

3. **Example Entries:**
   ```
   Purchase Order: 4500001234 to 4500001299
   Posting Date: 01.01.2024 to 31.03.2024
   ```

4. **Execute** (F8)

### Understanding the Output

**Display Structure:**
```
PO: 4500001234 | Vendor: ABC Corp | Incoterms: CIF | Payment: N30
├─ Currency: USD
│  ├─ GR (Line Type: GR)
│  │  └─ Item 10: Material M123 | 100 PC | Local: 50,000 EGP | Doc: 10,000 USD
│  ├─ Freight (Line Type: COND)
│  │  └─ Item 10: Invoice 5100789 | Local: 2,500 EGP | Doc: 500 USD
│  ├─ Customs (Line Type: COND)
│  │  └─ Item 10: Invoice 5100789 | Local: 5,000 EGP | Doc: 1,000 USD
│  └─ Subtotal: 57,500 EGP / 11,500 USD
```

**Key Elements:**
- **Line Type 'GR'**: Original goods receipt value
- **Line Type 'COND'**: Additional charges from invoices
- **SHKZG**: S = Debit (+), H = Credit (-)
- **XBLNR**: Vendor's invoice reference number

### ALV Functions
- **Expand/Collapse**: Use subtotal arrows
- **Export**: List → Export → Spreadsheet
- **Filter**: By condition type, currency, or PO
- **Save Layout**: For repeated use
- **Print**: With subtotals maintained

## Troubleshooting

### "No data found"
**Causes & Solutions:**
- No GRs in date range → Expand posting date selection
- Wrong movement type → Verify BEWTP = 'Q' in your system
- No POs selected → Check PO number format
- Authorization issue → Check access to EKBE/EKBZ tables

### "Conditions showing as codes (ZFRT, ZCST)"
**Causes & Solutions:**
- Condition not mapped → Add to map_condition_name form
- Wrong condition type → Verify with ME23N conditions tab
- Case sensitivity → Check exact condition code
- Missing WHEN OTHERS → Ensure default case exists

### "Wrong currency displayed"
**Causes & Solutions:**
- Didn't update both locations → Search for 'EGP' and replace all
- Currency not maintained → Check T001 for company code
- Document currency missing → Verify EKKO-WAERS populated
- Exchange rate issue → Not affected (shows original currencies)

### "Missing invoice charges"
**Causes & Solutions:**
- Wrong movement types → Check VGABE = '2' or '3' in EKBZ
- Invoice not posted → Verify in MIR4/MIRO
- Different posting date → Expand date range
- Conditions not transferred → Check invoice posting config

### "Performance issues"
**Causes & Solutions:**
- Large date range → Limit to 1-3 months
- Too many POs → Use PO selection
- Missing indexes → Contact BASIS team
- Run in background → Use F9 for large selections

### "Material descriptions missing"
**Causes & Solutions:**
- Language issue → Check MAKT entries for your language
- Material not extended → Verify material exists in plant
- Authorization → Check material display authorization
- Deletion flag → Ensure materials are active

### "Authorization error"
**Required Authorization Objects:**
- M_BEST_BSA (Purchase order display)
- M_RECH_BUK (Invoice display)
- F_BKPF_BUK (Accounting documents)
- M_MATE_MAT (Material master)

### "How to find my condition types"

1. go to SE16N → Enter T685 Table
   you will find Condition Types and they names

**💡 Pro Tip**: Run the report first with your conditions unmapped - the output will show the condition codes, then you can add proper descriptions!

---
## Attribution info:

  Author: Mohammed Abbas
  LinkedIn: [LinkedIn Profile](https://www.linkedin.com/in/mohammed-abbas-6067091b4/)
  Contribution: Original report development with AI assistance
  Date: June 2025
