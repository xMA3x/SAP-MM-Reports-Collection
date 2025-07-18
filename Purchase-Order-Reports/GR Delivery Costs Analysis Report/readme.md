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

**Common Example**:

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

## ❓ How to Find Your Condition Types

**Option 1 - Check a Purchase Order:**
1. SE16N → Enter T685 Table
2. you will find Condition Types and they names

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
