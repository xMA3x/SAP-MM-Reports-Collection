# 📊 GR Delivery Costs Analysis Report

[⬅️ Back to Purchase Order Reports](../)

## 📋 Overview

This ABAP report analyzes the total landed cost of purchased materials by combining:
- **Goods Receipt values** - The original material cost from GR postings
- **Additional charges** - All delivery-related costs (freight, customs, insurance, etc.) posted via invoice

Built with AI assistance to help SAP MM consultants calculate accurate total costs without technical support.

## 🎯 Report Goal

**Primary Purpose**: Calculate the COMPLETE cost of purchased materials by tracking:
1. Base material cost (from goods receipt)
2. All additional charges (from vendor invoices)
3. Total landed cost in both local and foreign currency

**Business Value**:
- Accurate product costing including all delivery charges
- Better vendor comparison (total cost, not just material price)
- Audit trail linking GRs to their associated costs
- Support for import cost analysis and budgeting

## ⚠️ CRITICAL: Company-Specific Customizations Required

### 1. **Local Currency** 💰
**What it is**: The currency used for internal reporting  
**Current setting**: `'EGP'` (Egyptian Pounds)  
**Where to change**: Lines ~178 and ~258
```abap
ls_final-waers_local = 'EGP'.  " ← CHANGE THIS TO YOUR CURRENCY
```
**Examples**:
- US companies: `'USD'`
- European companies: `'EUR'`
- Indian companies: `'INR'`

### 2. **Condition Types (Pricing Schema)** 📋
**What it is**: The codes used for different types of charges in your purchasing  
**Current setting**: Egypt-specific conditions with Arabic names  
**Where to change**: Form `map_condition_name` (line ~295)

**You must replace the ENTIRE condition mapping with YOUR company's conditions:**
```abap
FORM map_condition_name...
  CASE iv_kschl.
    " REPLACE THESE WITH YOUR CONDITION TYPES:
    WHEN 'ZADS'.  cv_text = 'مصاريف اضافية'.     " ← Your conditions
    WHEN 'ZBNK'.  cv_text = 'مصاريف بنكية'.      " ← Your descriptions
    " ... etc
```

**Common Examples by Region**:

*North America/Europe:*
```abap
WHEN 'FRA1'.  cv_text = 'Freight Charges'.
WHEN 'HD00'.  cv_text = 'Handling Fee'.
WHEN 'MWST'.  cv_text = 'VAT/Sales Tax'.
```

*India:*
```abap
WHEN 'JOCG'.  cv_text = 'CGST'.
WHEN 'JOSG'.  cv_text = 'SGST'.
WHEN 'ZCD1'.  cv_text = 'Custom Duty'.
```

*General Manufacturing:*
```abap
WHEN 'ZFR1'.  cv_text = 'Inbound Freight'.
WHEN 'ZIN1'.  cv_text = 'Insurance'.
WHEN 'ZPK1'.  cv_text = 'Packing Charges'.
```

### 3. **Language Settings** 🌐
**What it is**: Language for material and payment term descriptions  
**Current setting**: Mixed (Arabic condition names, English material texts)  
**Where to change**: Multiple SELECT statements

**To standardize to system language:**
```abap
" Find all instances of:
WHERE spras = 'EN'.

" Replace with:
WHERE spras = @sy-langu.
```

### 4. **Company Code** 🏢
**What it is**: Your organizational unit in SAP  
**When needed**: If you implement dynamic currency detection  
**Example**:
```abap
" Add to report header:
CONSTANTS: gc_bukrs TYPE bukrs VALUE '1000'.  " ← YOUR COMPANY CODE

" Use for currency detection:
SELECT SINGLE waers FROM t001 
  INTO ls_final-waers_local 
  WHERE bukrs = gc_bukrs.
```

## 📊 What the Report Shows

### Sample Output:
```
Purchase Order: 4500001234
├─ Goods Receipt (GR)
│  └─ Material: ABC123 | Qty: 100 | Value: $10,000 | Local: ₹750,000
│
├─ Additional Costs (COND)
│  ├─ Freight:        $500    | Local: ₹37,500
│  ├─ Customs:        $1,000  | Local: ₹75,000
│  ├─ Insurance:      $200    | Local: ₹15,000
│  └─ Handling:       $100    | Local: ₹7,500
│
└─ TOTAL LANDED COST: $11,800 | Local: ₹885,000
```

## 🛠️ Quick Implementation Guide

### Step 1: Identify Your Settings
Before touching the code, gather:
- [ ] Your local currency code
- [ ] List of ALL condition types used in purchasing
- [ ] Preferred language for displays
- [ ] Company code (if multiple)

### Step 2: Make the Changes

#### 2.1 Update Currency (2 places):
```abap
" Line ~178 and ~258
ls_final-waers_local = 'YOUR_CURRENCY'.  " e.g., 'USD', 'EUR', 'INR'
```

#### 2.2 Replace ALL Conditions:
```abap
FORM map_condition_name...
  CASE iv_kschl.
    " DELETE all existing conditions
    " ADD your company's conditions:
    WHEN 'YOUR_CONDITION_1'.  cv_text = 'Your Description 1'.
    WHEN 'YOUR_CONDITION_2'.  cv_text = 'Your Description 2'.
    " ... add all your conditions
    WHEN OTHERS.  cv_text = iv_kschl.
  ENDCASE.
ENDFORM.
```

#### 2.3 Fix Language (if needed):
```abap
" Search and replace all:
WHERE spras = 'EN'    →    WHERE spras = @sy-langu
WHERE spras = 'AR'    →    WHERE spras = @sy-langu
```

### Step 3: Create and Test
1. SE38 → Create Program `ZMM_GR_DELIVERY_COSTS_NEW`
2. Paste modified code
3. Activate
4. Test with ONE purchase order first
5. Verify all conditions display correctly

## ❓ How to Find Your Condition Types

**Option 1 - Check a Purchase Order:**
1. ME23N → Enter any import PO
2. Item Details → Conditions tab
3. Note all condition type codes

**Option 2 - Check Pricing Schema:**
1. SPRO → Materials Management → Purchasing → Conditions
2. Define Price Determination Process → Define Calculation Schema
3. Find your schema and list all conditions

**Option 3 - Ask Your MM Functional Lead:**
They should have a list of all purchasing condition types

## 🐛 Common Issues After Implementation

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| Wrong currency shown | Didn't update both locations | Search for 'EGP' and replace all |
| Conditions show as codes | Condition not mapped | Add to map_condition_name |
| No material descriptions | Wrong language code | Check language settings |
| No data found | Wrong movement types | Verify your PO has movement type 'Q' |

## 📄 License

This work is licensed under Creative Commons BY-NC-SA 4.0
- ✅ Free to use and modify
- ✅ Share improvements back
- ❌ No commercial distribution
- ⏰ Attribution required

## 🤝 Contributing

Found a bug? Have an improvement? Please contribute back to help others!

---

**Need Help?** Check the main repository discussions or create an issue.
