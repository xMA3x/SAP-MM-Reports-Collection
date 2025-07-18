# 📊 Subcontractor Stock Report with Values

## Overview

This ABAP report provides comprehensive visibility into materials stored at subcontractor locations, tracking both raw materials (special stock O) and finished goods produced through subcontracting. The report displays beginning and ending balances for any fiscal period with automatic valuation using SAP's moving average prices.

## Business Purpose

**Problems Solved:**
- No standard SAP report shows subcontractor stock with values
- Manual tracking of materials at vendor locations is time-consuming
- Difficulty reconciling physical inventory at subcontractors
- No visibility of finished goods produced via subcontracting
- Month-end closing requires manual calculations

**Business Value:**
- Complete audit trail for subcontractor inventory
- Automatic calculation of stock values for financial reporting
- Support for vendor reconciliation and disputes
- Efficiency analysis of subcontracting operations
- Compliance with inventory audit requirements

## Key Features

- **Dual Stock Tracking**: Both raw materials (ROH) and finished goods (FG)
- **Period Flexibility**: Any fiscal period range with historical data
- **Automatic Valuation**: Uses SAP moving average prices (MBEW/MBEWH)
- **Transaction Details**: Complete movement history with drill-down
- **Multi-Vendor**: Analyze multiple subcontractors simultaneously
- **ALV Display**: Hierarchical view with subtotals and export options
- **Currency Support**: Values in company's local currency
- **Performance Optimized**: Handles large data volumes efficiently

## ⚠️ CRITICAL: Company-Specific Customizations Required

### 1. **Company Code** (Line ~875)
```abap
WHERE bukrs = '1000'.  " ← CHANGE TO YOUR COMPANY CODE
```

### 2. **Default Currency** (Line ~877)
```abap
lv_waers = 'USD'.  " ← CHANGE TO YOUR LOCAL CURRENCY
```

### 3. **Fiscal Year Start** (Lines ~69 and ~239)
```abap
IF lv_current_month >= 7.  " ← CHANGE 7 TO YOUR FISCAL YEAR START MONTH
```
- July start = 7 (SAP default)
- April start = 4
- January start = 1

### 4. **Language** (Lines ~1687, ~1695, ~1703, ~1711)
```abap
WHERE spras = 'E'.  " ← CHANGE TO YOUR LANGUAGE CODE OR @sy-langu
```

### 5. **Movement Types** (Lines ~1180-1184 and ~1207-1209)
Verify these match your subcontracting process:
```abap
" Raw materials:
bwart = '101' OR '102' OR '541' OR '542' OR '543' OR '544' OR '701' OR '702'
" Finished goods:
bwart = '101' OR '102' OR '261' OR '262' OR '601' OR '602'
```

## Installation

1. **Open SE38** (ABAP Editor)

2. **Create New Program**
   - Program name: `ZSUBCONTRACTOR_STOCK_REPORT`
   - Type: `Executable program`
   - Status: `Test program`

3. **Copy Source Code**
   - Copy the entire ABAP code
   - Paste into the editor

4. **Make Required Customizations**
   - Update all items listed in CRITICAL section above
   - Save (Ctrl+S)

5. **Check Syntax** (Ctrl+F2)
   - Fix any errors before proceeding

6. **Activate** (Ctrl+F3)
   - Program is now ready to use

7. **Create Transaction Code** (Optional)
   - SE93 → New
   - Transaction code: `ZMM_SUBCON_STOCK`
   - Select "Program and selection screen"
   - Program: `ZSUBCONTRACTOR_STOCK_REPORT`

## Usage

### Running the Report

1. **Execute Transaction** `ZMM_SUBCON_STOCK` or run via SE38

2. **Selection Screen Parameters:**
   - **Material**: Optional - leave blank for all materials
   - **Supplier**: Required - select subcontractor vendor(s)
   - **From Year/Period**: Start of analysis period
   - **To Year/Period**: End of analysis period

3. **Example Entries:**
   ```
   Material: [blank for all]
   Supplier: 100523
   From Year/Period: 2024 / 01
   To Year/Period: 2024 / 03
   ```

4. **Execute** (F8)

### Understanding the Output

**Display Structure:**
```
Type | Material | Description | Vendor | Beg Stock | End Stock | Beg Value | End Value
ROH  | M100    | Steel Sheet | V100   | 1,000 PC  | 1,200 PC  | $5,000    | $6,000
     |         | 15.01.2024 101 +500 |           |           |           |
     |         | 20.02.2024 543 -300 |           |           |           |
FG   | F200    | Frame Assy  | V100   | 100 PC    | 150 PC    | $10,000   | $15,000
```

**Key Elements:**
- **ROH**: Raw materials at subcontractor
- **FG**: Finished goods from subcontracting
- **Line Type M**: Material summary with balances
- **Line Type T**: Individual transactions
- **Subtotals**: By stock type (ROH/FG)

### ALV Functions
- **Export**: Spreadsheet → Excel
- **Sort**: Click column headers
- **Filter**: Set filters icon
- **Subtotals**: View → Subtotals
- **Save Layout**: Settings → Layout → Save

## Troubleshooting

### "No stock data found for the selected criteria"
**Causes & Solutions:**
- No subcontractor stock exists → Check MSLB table directly
- Wrong vendor selected → Verify vendor is marked as subcontractor
- Wrong period → Check fiscal year configuration
- Authorization issue → Verify access to MSLB/MSLBH tables

### "Values showing as 0.00"
**Causes & Solutions:**
- No moving average price → Check MBEW for the material
- Wrong valuation area → Verify plant configuration
- Price unit issue → Check MBEW-PEINH is maintained
- Historical data missing → Run CKMLCP for historical periods

### "Wrong fiscal period calculations"
**Causes & Solutions:**
- Fiscal year variant different → Update the month check (line ~69)
- Period conversion wrong → Verify convert_periods_to_dates logic
- Year rollover issue → Check calculate_previous_period form

### "Missing finished goods"
**Causes & Solutions:**
- No subcontracting POs → Check EKPO-PSTYP = '3'
- Wrong movement types → Verify goods receipts with BWART = '101'
- Special stock indicator → FG should have SOBKZ = space
- Material filter too restrictive → Remove material selection

### "Performance issues"
**Causes & Solutions:**
- Date range too large → Limit to 3-6 months
- Too many vendors → Run for specific vendors
- Missing indexes → Check with BASIS team
- Run in background → Use F9 instead of F8

### "Authorization error"
**Required Authorization Objects:**
- M_MSEG_WMB (Material documents)
- M_MRES_BWA (Material movements)
- M_MATE_WRK (Material master)
- F_BKPF_BUK (Company code)

---

**💡 Pro Tip**: Always test with a single vendor and current month first to verify customizations are correct!
