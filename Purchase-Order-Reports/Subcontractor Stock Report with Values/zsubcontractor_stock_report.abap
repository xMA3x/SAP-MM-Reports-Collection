"""
SAP Subcontractor Stock Report with Values Report
Copyright (c) 2025 [Mohammed Abbas]
Licensed under CC BY-NC-SA 4.0
Built with AI assistance to democratize SAP reporting
"""

REPORT zsubcontractor_stock_report.

"-----------------------------------------------------------------------------
" Global Configuration and Data Structures
"-----------------------------------------------------------------------------
TABLES: 
  mslbh,    " Subcontractor Stock History
  mslb,     " Current Subcontractor Stock
  mara,     " Material Master
  makt,     " Material Description
  lfa1,     " Vendor Master
  mseg,     " Material Document Segment
  t134t,    " Material Type Description
  t023t,    " Material Group Description
  ekko,     " Purchase Order Header
  ekpo,     " Purchase Order Item
  MBEW,     " Material Valuation
  mbewh.    " Material Valuation History

"-----------------------------------------------------------------------------
" Selection Screen Definition
" Allows users to specify:
" - Material numbers
" - Vendor (mandatory)
" - Date range with fiscal year and period
"-----------------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE text-001.
  SELECT-OPTIONS: s_matnr FOR mara-matnr.
  SELECT-OPTIONS: s_lifnr FOR lfa1-lifnr OBLIGATORY.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(31) comm2 FOR FIELD p_fryr.
    PARAMETERS: p_fryr TYPE mslbh-lfgja OBLIGATORY.
    SELECTION-SCREEN COMMENT 38(1) text-002.
    PARAMETERS: p_frper TYPE mslbh-lfmon OBLIGATORY.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(31) comm3 FOR FIELD p_toyr.
    PARAMETERS: p_toyr TYPE mslbh-lfgja OBLIGATORY.
    SELECTION-SCREEN COMMENT 38(1) text-003.
    PARAMETERS: p_toper TYPE mslbh-lfmon OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK blk1.

"-----------------------------------------------------------------------------
" Initialization
" Sets default values for selection screen:
" - Current fiscal year if month >= 7
" - Previous fiscal year if month < 7
"-----------------------------------------------------------------------------
INITIALIZATION.
  DATA: lv_current_month TYPE i.

  comm2 = 'From Year/Period'.
  comm3 = 'To Year/Period'.

  %_s_matnr_%_app_%-text = 'Material'.
  %_s_lifnr_%_app_%-text = 'Supplier'.

  " Calculate default fiscal year based on current date
  lv_current_month = sy-datum+4(2).
  IF lv_current_month >= 7.
    p_fryr = sy-datum(4).
    p_toyr = sy-datum(4).
  ELSE.
    p_fryr = sy-datum(4) - 1.
    p_toyr = sy-datum(4) - 1.
  ENDIF.

  CLEAR: p_frper, p_toper.

"-----------------------------------------------------------------------------
" Type Definitions
" Defines structures for:
" - Material keys and stock data
" - Stock valuation
" - Finished goods tracking
" - Movement data
" - Display formatting
"-----------------------------------------------------------------------------
TYPES:
  " Structure for uniquely identifying materials in subcontractor stock
  BEGIN OF ty_material_key,
    matnr TYPE mslbh-matnr,  " Material number
    lifnr TYPE mslbh-lifnr,  " Vendor number
  END OF ty_material_key,

  " Structure for storing stock quantities by material and vendor
  BEGIN OF ty_stock_data,
    matnr TYPE mslbh-matnr,  " Material number
    lifnr TYPE mslbh-lifnr,  " Vendor number
    lblab TYPE mslbh-lblab,  " Stock quantity
  END OF ty_stock_data,

  " Structure for material valuation data with price and unit information
  BEGIN OF ty_stock_value,
    matnr TYPE matnr,        " Material number
    bwkey TYPE bwkey,        " Valuation area
    verpr TYPE verpr,        " Moving average price
    peinh TYPE peinh,        " Price unit
  END OF ty_stock_value,

  " Structure for tracking finished goods in subcontracting process
  BEGIN OF ty_fg_material,
    matnr TYPE matnr,        " Material number
    lifnr TYPE lifnr,        " Vendor number
  END OF ty_fg_material,

  " Structure for historical material valuation data
  BEGIN OF ty_mbewh_data,
    matnr TYPE matnr,        " Material number
    bwkey TYPE bwkey,        " Valuation area
    lfgja TYPE lfgja,        " Fiscal year
    lfmon TYPE lfmon,        " Fiscal period
    lbkum TYPE lbkum,        " Total stock quantity
    verpr TYPE verpr,        " Moving average price
    peinh TYPE peinh,        " Price unit
  END OF ty_mbewh_data,

  " Structure for current material valuation data
  BEGIN OF ty_mbew_data,
    matnr TYPE matnr,        " Material number
    bwkey TYPE bwkey,        " Valuation area
    lbkum TYPE lbkum,        " Total stock quantity
    verpr TYPE verpr,        " Moving average price
    peinh TYPE peinh,        " Price unit
  END OF ty_mbew_data,

  " Structure for material movement data from MSEG
  BEGIN OF ty_mseg_data,
    matnr      TYPE mseg-matnr,        " Material number
    lifnr      TYPE mseg-lifnr,        " Vendor number
    budat_mkpf TYPE mseg-budat_mkpf,   " Posting date
    bwart      TYPE mseg-bwart,        " Movement type
    menge      TYPE mseg-menge,        " Quantity
    meins      TYPE mseg-meins,        " Unit of measure
    mblnr      TYPE mseg-mblnr,        " Material document
    mjahr      TYPE mseg-mjahr,        " Material document year
    zeile      TYPE mseg-zeile,        " Document line item
    shkzg      TYPE mseg-shkzg,        " Debit/Credit indicator
    dmbtr      TYPE mseg-dmbtr,        " Amount in local currency
    waers      TYPE mseg-waers,        " Currency
    ebeln      TYPE mseg-ebeln,        " Purchase order number
    ebelp      TYPE mseg-ebelp,        " Purchase order item
    xblnr_mkpf TYPE mseg-xblnr_mkpf,   " Reference document number
  END OF ty_mseg_data,

  " Structure for ALV display combining material and transaction data
  BEGIN OF ty_display_data,
    line_type    TYPE char1,        " M=Material header, T=Transaction
    stock_type   TYPE char3,        " ROH=Raw material, FG=Finished good
    matnr        TYPE mslbh-matnr,  " Material number
    maktx        TYPE makt-maktx,   " Material description
    lifnr        TYPE mslbh-lifnr,  " Vendor number
    mtart        TYPE mara-mtart,   " Material type
    mtbez        TYPE t134t-mtbez,  " Material type description
    matkl        TYPE mara-matkl,   " Material group
    wgbez        TYPE t023t-wgbez,  " Material group description
    beg_stock    TYPE mslbh-lblab,  " Beginning stock quantity
    end_stock    TYPE mslbh-lblab,  " Ending stock quantity
    meins        TYPE mara-meins,   " Base unit of measure
    beg_value    TYPE dmbtr,        " Beginning stock value
    end_value    TYPE dmbtr,        " Ending stock value
    stock_waers  TYPE waers,        " Stock valuation currency
    " Transaction fields
    budat_mkpf   TYPE mseg-budat_mkpf,   " Posting date
    bwart        TYPE mseg-bwart,        " Movement type
    menge        TYPE mseg-menge,        " Movement quantity
    mblnr        TYPE mseg-mblnr,        " Material document
    mjahr        TYPE mseg-mjahr,        " Document year
    dmbtr        TYPE mseg-dmbtr,        " Movement amount
    waers        TYPE mseg-waers,        " Transaction currency
    shkzg        TYPE mseg-shkzg,        " Debit/Credit indicator
    ebeln        TYPE mseg-ebeln,        " Purchase order
    ebelp        TYPE mseg-ebelp,        " PO item
    xblnr_mkpf   TYPE mseg-xblnr_mkpf,   " Reference document
  END OF ty_display_data,

  " Structure for final consolidated stock data
  BEGIN OF ty_final_data,
    stock_type TYPE char3,         " ROH=Raw material, FG=Finished good
    matnr     TYPE mslbh-matnr,   " Material number
    maktx     TYPE makt-maktx,    " Material description
    lifnr     TYPE mslbh-lifnr,   " Vendor number
    mtart     TYPE mara-mtart,    " Material type
    mtbez     TYPE t134t-mtbez,   " Material type description
    matkl     TYPE mara-matkl,    " Material group
    wgbez     TYPE t023t-wgbez,   " Material group description
    beg_stock TYPE mslbh-lblab,   " Beginning stock quantity
    end_stock TYPE mslbh-lblab,   " Ending stock quantity
    meins     TYPE mara-meins,    " Base unit of measure
    beg_value TYPE dmbtr,         " Beginning stock value
    end_value TYPE dmbtr,         " Ending stock value
    waers     TYPE waers,         " Currency
  END OF ty_final_data.

" Global internal tables and variables for data processing
DATA: 
  gt_master_materials TYPE STANDARD TABLE OF ty_material_key,    " List of materials with special stock
  gt_fg_materials     TYPE STANDARD TABLE OF ty_fg_material,     " List of finished goods
  gt_beg_stock        TYPE STANDARD TABLE OF ty_stock_data,      " Beginning stock quantities
  gt_end_stock        TYPE STANDARD TABLE OF ty_stock_data,      " Ending stock quantities
  gt_fg_beg_stock     TYPE STANDARD TABLE OF ty_mbewh_data,      " Beginning FG stock with values
  gt_fg_end_stock     TYPE STANDARD TABLE OF ty_mbewh_data,      " Ending FG stock with values (historical)
  gt_fg_end_stock_mbew TYPE STANDARD TABLE OF ty_mbew_data,      " Ending FG stock with values (current)
  gt_mseg_data        TYPE STANDARD TABLE OF ty_mseg_data,       " Material movements
  gt_mseg_fg_data     TYPE STANDARD TABLE OF ty_mseg_data,       " FG material movements
  gt_final_data       TYPE STANDARD TABLE OF ty_final_data,      " Consolidated results
  gt_display_data     TYPE STANDARD TABLE OF ty_display_data,    " Data for ALV display
  gs_final_data       TYPE ty_final_data,                        " Work area for final data
  gv_beg_year         TYPE lfgja,                               " Beginning fiscal year
  gv_beg_period       TYPE lfmon,                               " Beginning fiscal period
  gv_use_mslb_for_end TYPE abap_bool,                          " Flag for current period processing
  gv_date_from        TYPE sy-datum,                           " Start date for movements
  gt_beg_stock_values TYPE STANDARD TABLE OF ty_stock_value,    " Beginning stock values
  gt_end_stock_values TYPE STANDARD TABLE OF ty_stock_value,    " Ending stock values
  gv_date_to          TYPE sy-datum.                           " End date for movements

"-----------------------------------------------------------------------------
" Input Validation
" Validates selection screen inputs:
" 1. Period range must be between 1 and 12
" 2. From date must be before or equal to To date
" 3. If same year, From period must be before or equal to To period
"-----------------------------------------------------------------------------
AT SELECTION-SCREEN.
  " Ensure periods are within valid fiscal period range
  IF p_frper > 12 OR p_frper < 1.
    MESSAGE 'From Period must be between 1 and 12' TYPE 'E'.
  ENDIF.

  IF p_toper > 12 OR p_toper < 1.
    MESSAGE 'To Period must be between 1 and 12' TYPE 'E'.
  ENDIF.

  " Ensure date range is chronologically valid
  IF p_fryr > p_toyr.
    MESSAGE 'From Year cannot be greater than To Year' TYPE 'E'.
  ELSEIF p_fryr = p_toyr AND p_frper > p_toper.
    MESSAGE 'From Period cannot be greater than To Period in the same year' TYPE 'E'.
  ENDIF.

"-----------------------------------------------------------------------------
" Main Processing Logic
" Executes the following steps:
" 1. Calculate previous period for beginning balance
" 2. Convert fiscal periods to calendar dates
" 3. Check if ending period is current period
" 4. Retrieve material master data
" 5. Process stock balances and movements
" 6. Build display data
"-----------------------------------------------------------------------------
START-OF-SELECTION.

  PERFORM calculate_previous_period.
  PERFORM convert_periods_to_dates.
  PERFORM check_current_period.

  " Get special stock materials (ROH)
  PERFORM get_master_material_list.

  " Always get finished goods materials - NO CHECKBOX CHECK
  PERFORM get_fg_materials.

  IF gt_master_materials IS INITIAL AND gt_fg_materials IS INITIAL.
    MESSAGE 'No stock data found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " Continue with the rest of the processing...
  PERFORM read_stock_balances.
  PERFORM read_mseg_transactions.
  PERFORM merge_stock_data.
  PERFORM get_descriptions.

  " Remove materials with zero stock
  DELETE gt_final_data WHERE beg_stock = 0 AND end_stock = 0.

  IF gt_final_data IS INITIAL.
    MESSAGE 'No materials with stock found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  PERFORM build_display_data.
  PERFORM display_alv.

"-----------------------------------------------------------------------------
" Form Routines
"-----------------------------------------------------------------------------

"----------------------------------------------------------------------
" calculate_previous_period
" Purpose: Calculates the previous fiscal period for beginning balance
" Parameters: None
" Returns: Sets global variables gv_beg_year and gv_beg_period
"----------------------------------------------------------------------
FORM calculate_previous_period.
  gv_beg_year   = p_fryr.
  gv_beg_period = p_frper.

  " Handle fiscal year rollover when current period is 1
  IF gv_beg_period = 1.
    gv_beg_period = 12.
    gv_beg_year = gv_beg_year - 1.
  ELSE.
    gv_beg_period = gv_beg_period - 1.
  ENDIF.
ENDFORM.

"----------------------------------------------------------------------
" convert_periods_to_dates
" Purpose: Converts fiscal year/period to calendar dates for MSEG selection
" Parameters: None
" Returns: Sets global variables gv_date_from and gv_date_to
"----------------------------------------------------------------------
FORM convert_periods_to_dates.
  DATA: lv_from_month TYPE i,
        lv_to_month   TYPE i,
        lv_from_year  TYPE numc4,
        lv_to_year    TYPE numc4,
        lv_last_day   TYPE i,
        lv_month_str  TYPE numc2,
        lv_day_str    TYPE numc2.

  " Convert fiscal periods to calendar months
  " SAP fiscal year starts in April, so period 1 = July, period 7 = January
  IF p_frper <= 6.
    lv_from_month = p_frper + 6.
    lv_from_year = p_fryr.
  ELSE.
    lv_from_month = p_frper - 6.
    lv_from_year = p_fryr + 1.
  ENDIF.

  IF p_toper <= 6.
    lv_to_month = p_toper + 6.
    lv_to_year = p_toyr.
  ELSE.
    lv_to_month = p_toper - 6.
    lv_to_year = p_toyr + 1.
  ENDIF.

  " Build start date (first day of from-month)
  lv_month_str = lv_from_month.
  CONCATENATE lv_from_year lv_month_str '01' INTO gv_date_from.

  " Calculate last day of to-month considering month lengths and leap years
  CASE lv_to_month.
    WHEN 1 OR 3 OR 5 OR 7 OR 8 OR 10 OR 12.
      lv_last_day = 31.
    WHEN 4 OR 6 OR 9 OR 11.
      lv_last_day = 30.
    WHEN 2.
      " Check for leap year using standard formula
      IF ( lv_to_year MOD 4 = 0 AND lv_to_year MOD 100 <> 0 ) OR ( lv_to_year MOD 400 = 0 ).
        lv_last_day = 29.
      ELSE.
        lv_last_day = 28.
      ENDIF.
  ENDCASE.

  " Build end date (last day of to-month)
  lv_month_str = lv_to_month.
  lv_day_str = lv_last_day.
  CONCATENATE lv_to_year lv_month_str lv_day_str INTO gv_date_to.
ENDFORM.

"----------------------------------------------------------------------
" check_current_period
" Purpose: Determines if ending period is current fiscal period
" Parameters: None
" Returns: Sets global flag gv_use_mslb_for_end
" Note: Current period uses MSLB table, historical periods use MSLBH
"----------------------------------------------------------------------
FORM check_current_period.
  DATA: lv_current_year   TYPE lfgja,
        lv_current_period TYPE lfmon,
        lv_current_month  TYPE i.

  " Calculate current fiscal period from system date
  lv_current_month = sy-datum+4(2).

  IF lv_current_month >= 7.
    lv_current_period = lv_current_month - 6.
    lv_current_year = sy-datum(4).
  ELSE.
    lv_current_period = lv_current_month + 6.
    lv_current_year = sy-datum(4) - 1.
  ENDIF.

  " Set flag based on whether ending period matches current period
  IF p_toyr = lv_current_year AND p_toper = lv_current_period.
    gv_use_mslb_for_end = abap_true.  " Use current period table
  ELSE.
    gv_use_mslb_for_end = abap_false. " Use historical table
  ENDIF.
ENDFORM.

"----------------------------------------------------------------------
" get_fg_materials
" Purpose: Identifies finished goods produced through subcontracting
" Parameters: None
" Returns: Populates gt_fg_materials with FG materials
" Logic:
" 1. Get subcontract POs for selected vendors
" 2. Get PO items with subcontracting indicator
" 3. Find FG materials from goods receipt postings
" 4. Exclude materials already in special stock
"----------------------------------------------------------------------
FORM get_fg_materials.
  " Temporary structures for database selections
  TYPES: BEGIN OF ty_ekko_temp,
           ebeln TYPE ekko-ebeln,  " Purchase order number
           lifnr TYPE ekko-lifnr,  " Vendor number
         END OF ty_ekko_temp,

         BEGIN OF ty_ekpo_temp,
           ebeln TYPE ekpo-ebeln,  " Purchase order number
           ebelp TYPE ekpo-ebelp,  " Item number
           matnr TYPE ekpo-matnr,  " Material number
         END OF ty_ekpo_temp,

         BEGIN OF ty_mseg_temp,
           matnr TYPE mseg-matnr,  " Material number
           ebeln TYPE mseg-ebeln,  " Purchase order number
           ebelp TYPE mseg-ebelp,  " Item number
           lifnr TYPE mseg-lifnr,  " Vendor number
         END OF ty_mseg_temp.

  DATA: lt_ekko TYPE STANDARD TABLE OF ty_ekko_temp,
        lt_ekpo TYPE STANDARD TABLE OF ty_ekpo_temp,
        lt_mseg TYPE STANDARD TABLE OF ty_mseg_temp,
        ls_ekko TYPE ty_ekko_temp,
        ls_ekpo TYPE ty_ekpo_temp,
        ls_mseg TYPE ty_mseg_temp,
        ls_fg   TYPE ty_fg_material.

  " Step 1: Get active subcontract purchase orders for selected vendors
  SELECT ebeln lifnr
    FROM ekko
    INTO TABLE lt_ekko
    WHERE lifnr IN s_lifnr
      AND bstyp = 'F'      " Standard PO
      AND loekz = space.   " Not deleted

  IF lt_ekko IS INITIAL.
    RETURN.
  ENDIF.

  " Step 2: Get subcontract items from selected POs
  SELECT ebeln ebelp matnr
    FROM ekpo
    INTO TABLE lt_ekpo
    FOR ALL ENTRIES IN lt_ekko
    WHERE ebeln = lt_ekko-ebeln
      AND pstyp = '3'      " Subcontracting
      AND loekz = space.   " Not deleted

  IF lt_ekpo IS INITIAL.
    RETURN.
  ENDIF.

  " Step 3: Find finished goods from goods receipt postings
  SELECT DISTINCT matnr ebeln ebelp lifnr
    FROM mseg
    INTO TABLE lt_mseg
    FOR ALL ENTRIES IN lt_ekpo
    WHERE ebeln = lt_ekpo-ebeln
      AND ebelp = lt_ekpo-ebelp
      AND bwart = '101'    " Goods receipt
      AND matnr IN s_matnr " Apply material filter
      AND sobkz = space.   " Regular stock

  " Build list of finished goods, excluding special stock materials
  LOOP AT lt_mseg INTO ls_mseg.
    CLEAR ls_fg.
    ls_fg-matnr = ls_mseg-matnr.
    ls_fg-lifnr = ls_mseg-lifnr.

    " Skip if material is already in special stock
    READ TABLE gt_master_materials TRANSPORTING NO FIELDS
      WITH KEY matnr = ls_fg-matnr
               lifnr = ls_fg-lifnr.
    IF sy-subrc <> 0.  " Not found in special stock
      APPEND ls_fg TO gt_fg_materials.
    ENDIF.
  ENDLOOP.

  " Remove duplicate entries
  SORT gt_fg_materials BY matnr lifnr.
  DELETE ADJACENT DUPLICATES FROM gt_fg_materials COMPARING matnr lifnr.
ENDFORM.

"----------------------------------------------------------------------
" read_stock_balances
" Purpose: Reads stock quantities and values for both raw materials and FG
" Parameters: None
" Returns: Populates the following global tables:
"   - gt_beg_stock/gt_end_stock: Special stock quantities
"   - gt_beg_stock_values/gt_end_stock_values: Stock values
"   - gt_fg_beg_stock/gt_fg_end_stock: FG stock with values
" Logic:
"   1. Read special stock quantities for raw materials
"   2. Read stock values for raw materials
"   3. Read stock quantities and values for finished goods
"----------------------------------------------------------------------
FORM read_stock_balances.
  DATA: lt_werks TYPE STANDARD TABLE OF t001w-werks,
        lv_werks TYPE t001w-werks.

  " Step 1a: Read beginning balance for raw materials (special stock)
  SELECT matnr, lifnr, lblab
    FROM mslbh
    INTO TABLE @gt_beg_stock
    FOR ALL ENTRIES IN @gt_master_materials
    WHERE matnr = @gt_master_materials-matnr
      AND lifnr = @gt_master_materials-lifnr
      AND lfgja = @gv_beg_year
      AND lfmon = @gv_beg_period.

  " Step 1b: Read ending balance for raw materials
  " Use current table (MSLB) for current period, historical table (MSLBH) otherwise
  IF gv_use_mslb_for_end = abap_true.
    SELECT matnr, lifnr, lblab
      FROM mslb
      INTO TABLE @gt_end_stock
      FOR ALL ENTRIES IN @gt_master_materials
      WHERE matnr = @gt_master_materials-matnr
        AND lifnr = @gt_master_materials-lifnr
        AND lfgja = @p_toyr
        AND lfmon = @p_toper.
  ELSE.
    SELECT matnr, lifnr, lblab
      FROM mslbh
      INTO TABLE @gt_end_stock
      FOR ALL ENTRIES IN @gt_master_materials
      WHERE matnr = @gt_master_materials-matnr
        AND lifnr = @gt_master_materials-lifnr
        AND lfgja = @p_toyr
        AND lfmon = @p_toper.
  ENDIF.

  " Get list of plants for valuation data
  SELECT werks FROM t001w INTO TABLE lt_werks.

  " Step 2a: Read beginning values for raw materials
  IF gt_master_materials IS NOT INITIAL.
    SELECT matnr, bwkey, verpr, peinh
      FROM mbewh
      INTO TABLE @gt_beg_stock_values
      FOR ALL ENTRIES IN @gt_master_materials
      WHERE matnr = @gt_master_materials-matnr
        AND lfgja = @gv_beg_year
        AND lfmon = @gv_beg_period.

    " Step 2b: Read ending values for raw materials
    IF gv_use_mslb_for_end = abap_true.
      " Current period - use current valuation
      SELECT matnr, bwkey, verpr, peinh
        FROM mbew
        INTO TABLE @gt_end_stock_values
        FOR ALL ENTRIES IN @gt_master_materials
        WHERE matnr = @gt_master_materials-matnr.
    ELSE.
      " Historical period - use historical valuation
      SELECT matnr, bwkey, verpr, peinh
        FROM mbewh
        INTO TABLE @gt_end_stock_values
        FOR ALL ENTRIES IN @gt_master_materials
        WHERE matnr = @gt_master_materials-matnr
          AND lfgja = @p_toyr
          AND lfmon = @p_toper.
    ENDIF.
  ENDIF.

  " Step 3: Process finished goods stock if any exist
  IF gt_fg_materials IS NOT INITIAL.
    " Step 3a: Read beginning stock for finished goods (always historical)
    SELECT matnr, bwkey, lfgja, lfmon, lbkum, verpr, peinh
      FROM mbewh
      INTO TABLE @gt_fg_beg_stock
      FOR ALL ENTRIES IN @gt_fg_materials
      WHERE matnr = @gt_fg_materials-matnr
        AND lfgja = @gv_beg_year
        AND lfmon = @gv_beg_period.

    " Step 3b: Read ending stock for finished goods
    IF gv_use_mslb_for_end = abap_true.
      " Current period - use current valuation
      SELECT matnr, bwkey, lbkum, verpr, peinh
        FROM mbew
        INTO TABLE @gt_fg_end_stock_mbew
        FOR ALL ENTRIES IN @gt_fg_materials
        WHERE matnr = @gt_fg_materials-matnr.
    ELSE.
      " Historical period - use historical valuation
      SELECT matnr, bwkey, lfgja, lfmon, lbkum, verpr, peinh
        FROM mbewh
        INTO TABLE @gt_fg_end_stock
        FOR ALL ENTRIES IN @gt_fg_materials
        WHERE matnr = @gt_fg_materials-matnr
          AND lfgja = @p_toyr
          AND lfmon = @p_toper.
    ENDIF.
  ENDIF.
ENDFORM.

"----------------------------------------------------------------------
" read_mseg_transactions
" Purpose: Reads material movements for both raw materials and finished goods
" Parameters: None
" Returns: Populates gt_mseg_data with all relevant movements
" Logic:
"   1. Read movements for raw materials (special stock)
"   2. Read movements for finished goods (regular stock)
"   3. Process quantities and amounts (make reversals negative)
"   4. Sort results by material, vendor, and posting date
" Movement Types:
"   Raw Materials:
"     - 101/102: Goods receipt/reversal
"     - 541/542: Transfer posting/reversal
"     - 543/544: Special stock transfer/reversal
"     - 701/702: Consumption/reversal
"   Finished Goods:
"     - 101/102: Goods receipt/reversal
"     - 261/262: Consumption/reversal
"     - 601/602: Delivery/reversal
"----------------------------------------------------------------------
FORM read_mseg_transactions.
  DATA: ls_mseg_temp TYPE ty_mseg_data.

  " Clear transaction tables before processing
  CLEAR: gt_mseg_data, gt_mseg_fg_data.

  " Step 1: Read movements for raw materials (special stock)
  IF gt_master_materials IS NOT INITIAL.
    SELECT matnr, lifnr, budat_mkpf, bwart, menge, meins, mblnr, mjahr,
           zeile, shkzg, dmbtr, waers, ebeln, ebelp, xblnr_mkpf
      FROM mseg
      INTO CORRESPONDING FIELDS OF TABLE @gt_mseg_data
      FOR ALL ENTRIES IN @gt_master_materials
      WHERE matnr = @gt_master_materials-matnr
        AND lifnr = @gt_master_materials-lifnr
        AND budat_mkpf >= @gv_date_from
        AND budat_mkpf <= @gv_date_to
        AND sobkz = 'O'    " Special stock indicator
        AND ( bwart = '101' OR bwart = '102' OR  " GR/Reversal
              bwart = '541' OR bwart = '542' OR  " Transfer/Reversal
              bwart = '543' OR bwart = '544' OR  " Special stock transfer
              bwart = '701' OR bwart = '702' ).  " Consumption/Reversal

    " Apply material selection criteria if specified
    IF s_matnr[] IS NOT INITIAL.
      DELETE gt_mseg_data WHERE matnr NOT IN s_matnr.
    ENDIF.
  ENDIF.

  " Step 2: Read movements for finished goods
  IF gt_fg_materials IS NOT INITIAL.
    SELECT matnr, lifnr, budat_mkpf, bwart, menge, meins, mblnr, mjahr,
           zeile, shkzg, dmbtr, waers, ebeln, ebelp, xblnr_mkpf
      FROM mseg
      INTO CORRESPONDING FIELDS OF TABLE @gt_mseg_fg_data
      FOR ALL ENTRIES IN @gt_fg_materials
      WHERE matnr = @gt_fg_materials-matnr
        AND lifnr = @gt_fg_materials-lifnr
        AND budat_mkpf >= @gv_date_from
        AND budat_mkpf <= @gv_date_to
        AND sobkz = @space  " Regular stock
        AND ( bwart = '101' OR bwart = '102' OR  " GR/Reversal
              bwart = '261' OR bwart = '262' OR  " Consumption/Reversal
              bwart = '601' OR bwart = '602' ).  " Delivery/Reversal

    " Apply material selection criteria if specified
    IF s_matnr[] IS NOT INITIAL.
      DELETE gt_mseg_fg_data WHERE matnr NOT IN s_matnr.
    ENDIF.

    " Combine FG movements with main transaction table
    APPEND LINES OF gt_mseg_fg_data TO gt_mseg_data.
  ENDIF.

  " Ensure all transactions are within date range
  DELETE gt_mseg_data WHERE budat_mkpf < gv_date_from
                        OR budat_mkpf > gv_date_to.

  " Process quantities and amounts
  LOOP AT gt_mseg_data INTO ls_mseg_temp.
    " Make reversal quantities and amounts negative
    IF ls_mseg_temp-shkzg = 'H'.  " Credit indicator
      ls_mseg_temp-menge = ls_mseg_temp-menge * -1.
      ls_mseg_temp-dmbtr = ls_mseg_temp-dmbtr * -1.
    ENDIF.
    MODIFY gt_mseg_data FROM ls_mseg_temp.
  ENDLOOP.

  " Sort for efficient processing
  SORT gt_mseg_data BY matnr lifnr budat_mkpf.
ENDFORM.

"-----------------------------------------------------------------------------
" Modified Form: Merge Stock Data (now handles both ROH and FG)
"-----------------------------------------------------------------------------
"----------------------------------------------------------------------
" merge_stock_data
" Purpose: Consolidates stock quantities and values for both material types
" Parameters: None
" Returns: Populates gt_final_data with consolidated stock information
" Logic:
"   1. Get company currency for valuation
"   2. Process raw materials (ROH):
"      - Combine quantities from special stock
"      - Calculate values using moving average price
"   3. Process finished goods (FG):
"      - Sum quantities across plants
"      - Calculate values using current/historical prices
"   4. Store results in gt_final_data for display
"----------------------------------------------------------------------
FORM merge_stock_data.
  DATA: ls_master    TYPE ty_material_key,
        ls_fg        TYPE ty_fg_material,
        ls_beg       TYPE ty_stock_data,
        ls_end       TYPE ty_stock_data,
        ls_mbewh_beg TYPE ty_mbewh_data,
        ls_mbewh_end TYPE ty_mbewh_data,
        ls_mbew_end  TYPE ty_mbew_data,
        ls_value_beg TYPE ty_stock_value,
        ls_value_end TYPE ty_stock_value,
        lv_beg_total TYPE lbkum,
        lv_end_total TYPE lbkum,
        lv_beg_value TYPE dmbtr,
        lv_end_value TYPE dmbtr,
        lv_unit_price TYPE p DECIMALS 5,
        lv_price_unit TYPE peinh.

  " Get company currency for stock valuation
  SELECT SINGLE waers FROM t001 INTO @DATA(lv_waers) WHERE bukrs = '1000'.
  IF sy-subrc <> 0.
    lv_waers = 'USD'.  " Default if company code not found
  ENDIF.

  " Step 1: Process raw materials with special stock
  LOOP AT gt_master_materials INTO ls_master.
    CLEAR: gs_final_data, lv_beg_value, lv_end_value.
    gs_final_data-stock_type = 'ROH'.
    gs_final_data-matnr = ls_master-matnr.
    gs_final_data-lifnr = ls_master-lifnr.
    gs_final_data-waers = lv_waers.

    " Get beginning stock quantity
    READ TABLE gt_beg_stock INTO ls_beg
      WITH KEY matnr = ls_master-matnr
               lifnr = ls_master-lifnr.
    IF sy-subrc = 0.
      gs_final_data-beg_stock = ls_beg-lblab.
    ENDIF.

    " Get ending stock quantity
    READ TABLE gt_end_stock INTO ls_end
      WITH KEY matnr = ls_master-matnr
               lifnr = ls_master-lifnr.
    IF sy-subrc = 0.
      gs_final_data-end_stock = ls_end-lblab.
    ENDIF.

    " Calculate beginning stock value using first found price
    READ TABLE gt_beg_stock_values INTO ls_value_beg
      WITH KEY matnr = ls_master-matnr.
    IF sy-subrc = 0 AND ls_value_beg-peinh > 0.
      lv_unit_price = ls_value_beg-verpr / ls_value_beg-peinh.
      gs_final_data-beg_value = gs_final_data-beg_stock * lv_unit_price.
    ENDIF.

    " Calculate ending stock value using first found price
    READ TABLE gt_end_stock_values INTO ls_value_end
      WITH KEY matnr = ls_master-matnr.
    IF sy-subrc = 0 AND ls_value_end-peinh > 0.
      lv_unit_price = ls_value_end-verpr / ls_value_end-peinh.
      gs_final_data-end_value = gs_final_data-end_stock * lv_unit_price.
    ENDIF.

    APPEND gs_final_data TO gt_final_data.
  ENDLOOP.

  " Step 2: Process finished goods across all plants
  LOOP AT gt_fg_materials INTO ls_fg.
    CLEAR: gs_final_data, lv_beg_total, lv_end_total, lv_beg_value, lv_end_value.
    gs_final_data-stock_type = 'FG'.
    gs_final_data-matnr = ls_fg-matnr.
    gs_final_data-lifnr = ls_fg-lifnr.
    gs_final_data-waers = lv_waers.

    " Sum beginning stock and value across plants
    LOOP AT gt_fg_beg_stock INTO ls_mbewh_beg
      WHERE matnr = ls_fg-matnr.
      lv_beg_total = lv_beg_total + ls_mbewh_beg-lbkum.

      " Calculate value using moving average price
      IF ls_mbewh_beg-peinh > 0.
        lv_unit_price = ls_mbewh_beg-verpr / ls_mbewh_beg-peinh.
        lv_beg_value = lv_beg_value + ( ls_mbewh_beg-lbkum * lv_unit_price ).
      ENDIF.
    ENDLOOP.
    gs_final_data-beg_stock = lv_beg_total.
    gs_final_data-beg_value = lv_beg_value.

    " Sum ending stock and value across plants
    IF gv_use_mslb_for_end = abap_true.
      " Current period: Use current valuation data
      LOOP AT gt_fg_end_stock_mbew INTO ls_mbew_end
        WHERE matnr = ls_fg-matnr.
        lv_end_total = lv_end_total + ls_mbew_end-lbkum.

        " Calculate value using current moving average price
        IF ls_mbew_end-peinh > 0.
          lv_unit_price = ls_mbew_end-verpr / ls_mbew_end-peinh.
          lv_end_value = lv_end_value + ( ls_mbew_end-lbkum * lv_unit_price ).
        ENDIF.
      ENDLOOP.
    ELSE.
      " Historical period: Use historical valuation data
      LOOP AT gt_fg_end_stock INTO ls_mbewh_end
        WHERE matnr = ls_fg-matnr.
        lv_end_total = lv_end_total + ls_mbewh_end-lbkum.

        " Calculate value using historical moving average price
        IF ls_mbewh_end-peinh > 0.
          lv_unit_price = ls_mbewh_end-verpr / ls_mbewh_end-peinh.
          lv_end_value = lv_end_value + ( ls_mbewh_end-lbkum * lv_unit_price ).
        ENDIF.
      ENDLOOP.
    ENDIF.
    gs_final_data-end_stock = lv_end_total.
    gs_final_data-end_value = lv_end_value.

    APPEND gs_final_data TO gt_final_data.
  ENDLOOP.
ENDFORM.

"-----------------------------------------------------------------------------
" Modified Form: Build Display Data (now shows stock type)
"-----------------------------------------------------------------------------
"----------------------------------------------------------------------
" build_display_data
" Purpose: Prepares data for ALV grid display with material and transaction details
" Parameters: None
" Returns: Populates gt_display_data with formatted display records
" Logic:
"   1. Sort consolidated data by stock type and material
"   2. For each material:
"      - Create material header record (line_type = 'M')
"      - Add associated transaction records (line_type = 'T')
"      - Add placeholder if no transactions exist
"   3. Maintain master data consistency across all records
"----------------------------------------------------------------------
FORM build_display_data.
  DATA: ls_display     TYPE ty_display_data,
        ls_mseg        TYPE ty_mseg_data,
        lv_transaction_count TYPE i.

  CLEAR gt_display_data.

  " Sort for consistent display order
  SORT gt_final_data BY stock_type matnr.

  " Process each material and its transactions
  LOOP AT gt_final_data INTO gs_final_data.
    CLEAR ls_display.

    " Create material header record
    ls_display-line_type = 'M'.            " Material header indicator
    ls_display-stock_type = gs_final_data-stock_type.
    ls_display-matnr = gs_final_data-matnr.
    ls_display-maktx = gs_final_data-maktx.
    ls_display-lifnr = gs_final_data-lifnr.
    ls_display-mtart = gs_final_data-mtart.
    ls_display-mtbez = gs_final_data-mtbez.
    ls_display-matkl = gs_final_data-matkl.
    ls_display-wgbez = gs_final_data-wgbez.
    ls_display-beg_stock = gs_final_data-beg_stock.
    ls_display-end_stock = gs_final_data-end_stock.
    ls_display-meins = gs_final_data-meins.
    ls_display-beg_value = gs_final_data-beg_value.
    ls_display-end_value = gs_final_data-end_value.
    ls_display-stock_waers = gs_final_data-waers.
    APPEND ls_display TO gt_display_data.

    " Add transaction records for this material
    lv_transaction_count = 0.
    LOOP AT gt_mseg_data INTO ls_mseg WHERE matnr = gs_final_data-matnr
                                       AND lifnr = gs_final_data-lifnr.

      " Only include transactions within selected period
      IF ls_mseg-budat_mkpf >= gv_date_from AND ls_mseg-budat_mkpf <= gv_date_to.
        CLEAR ls_display.
        " Set transaction record indicators
        ls_display-line_type = 'T'.        " Transaction indicator
        ls_display-stock_type = gs_final_data-stock_type.

        " Maintain material master data consistency
        ls_display-matnr = gs_final_data-matnr.
        ls_display-maktx = gs_final_data-maktx.
        ls_display-lifnr = gs_final_data-lifnr.
        ls_display-mtart = gs_final_data-mtart.
        ls_display-mtbez = gs_final_data-mtbez.
        ls_display-matkl = gs_final_data-matkl.
        ls_display-wgbez = gs_final_data-wgbez.
        ls_display-meins = gs_final_data-meins.
        ls_display-stock_waers = gs_final_data-waers.

        " Add transaction details
        ls_display-budat_mkpf = ls_mseg-budat_mkpf.
        ls_display-bwart = ls_mseg-bwart.
        ls_display-menge = ls_mseg-menge.
        ls_display-mblnr = ls_mseg-mblnr.
        ls_display-mjahr = ls_mseg-mjahr.
        ls_display-dmbtr = ls_mseg-dmbtr.
        ls_display-waers = ls_mseg-waers.
        ls_display-shkzg = ls_mseg-shkzg.
        ls_display-ebeln = ls_mseg-ebeln.
        ls_display-ebelp = ls_mseg-ebelp.
        ls_display-xblnr_mkpf = ls_mseg-xblnr_mkpf.
        APPEND ls_display TO gt_display_data.
        lv_transaction_count = lv_transaction_count + 1.
      ENDIF.
    ENDLOOP.

    " Add placeholder if no transactions found
    IF lv_transaction_count = 0.
      CLEAR ls_display.
      ls_display-line_type = 'T'.
      ls_display-stock_type = gs_final_data-stock_type.
      ls_display-matnr = gs_final_data-matnr.
      ls_display-maktx = 'No transactions found in period'.
      ls_display-lifnr = gs_final_data-lifnr.
      ls_display-mtart = gs_final_data-mtart.
      ls_display-mtbez = gs_final_data-mtbez.
      ls_display-matkl = gs_final_data-matkl.
      ls_display-wgbez = gs_final_data-wgbez.
      ls_display-meins = gs_final_data-meins.
      ls_display-stock_waers = gs_final_data-waers.
      APPEND ls_display TO gt_display_data.
    ENDIF.
  ENDLOOP.
ENDFORM.

"-----------------------------------------------------------------------------
" Modified Form: Display ALV (now includes stock type column)
"-----------------------------------------------------------------------------
"----------------------------------------------------------------------
" display_alv
" Purpose: Configures and displays the ALV grid with stock and transaction data
" Parameters: None
" Returns: None
" Configuration:
"   1. Basic Settings:
"      - Enable all standard functions
"      - Set display settings (striped pattern, header)
"      - Optimize column widths
"   2. Sort Configuration:
"      - Primary: Stock type (with subtotals)
"      - Secondary: Material number
"      - Tertiary: Line type and posting date
"   3. Column Settings:
"      - Hide technical fields
"      - Set column headers and tooltips
"      - Configure key fields
"   4. Aggregation:
"      - Total quantities and amounts
"   5. Layout:
"      - Enable layout saving
"      - Set default layout
"----------------------------------------------------------------------
FORM display_alv.
  DATA: lo_alv         TYPE REF TO cl_salv_table,
        lo_columns     TYPE REF TO cl_salv_columns,
        lo_column      TYPE REF TO cl_salv_column_table,
        lo_functions   TYPE REF TO cl_salv_functions,
        lo_display     TYPE REF TO cl_salv_display_settings,
        lo_layout      TYPE REF TO cl_salv_layout,
        lo_sorts       TYPE REF TO cl_salv_sorts,
        lo_aggregations TYPE REF TO cl_salv_aggregations,
        ls_key         TYPE salv_s_layout_key.

  TRY.
      " Create ALV grid instance
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = gt_display_data ).

      " Enable standard ALV functionality
      lo_functions = lo_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Configure display settings
      lo_display = lo_alv->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).
      lo_display->set_list_header( 'Subcontractor Stock Report with Values' ).

      " Optimize column widths
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Configure sort sequence
      lo_sorts = lo_alv->get_sorts( ).
      lo_sorts->add_sort( columnname = 'STOCK_TYPE' subtotal = abap_true ).
      lo_sorts->add_sort( columnname = 'MATNR' ).
      lo_sorts->add_sort( columnname = 'LINE_TYPE' ).
      lo_sorts->add_sort( columnname = 'BUDAT_MKPF' ).

      " Configure column properties
      " Technical Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'LINE_TYPE' ).
          lo_column->set_visible( abap_false ).  " Hide technical indicator
        CATCH cx_salv_not_found.
      ENDTRY.

      " Key Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'STOCK_TYPE' ).
          lo_column->set_medium_text( 'Stock Type' ).
          lo_column->set_short_text( 'Type' ).
          lo_column->set_key( abap_true ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MATNR' ).
          lo_column->set_medium_text( 'Material' ).
          lo_column->set_key( abap_true ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Material Data Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'MAKTX' ).
          lo_column->set_medium_text( 'Description' ).
          lo_column->set_long_text( 'Material Description' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'LIFNR' ).
          lo_column->set_medium_text( 'Vendor' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MTART' ).
          lo_column->set_medium_text( 'Mat.Type' ).
          lo_column->set_short_text( 'Type' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MTBEZ' ).
          lo_column->set_medium_text( 'Type Desc.' ).
          lo_column->set_long_text( 'Material Type Description' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MATKL' ).
          lo_column->set_medium_text( 'Mat.Group' ).
          lo_column->set_short_text( 'Grp' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'WGBEZ' ).
          lo_column->set_medium_text( 'Group Desc.' ).
          lo_column->set_long_text( 'Material Group Description' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Stock Quantity Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'BEG_STOCK' ).
          lo_column->set_medium_text( 'Begin Stock' ).
          lo_column->set_short_text( 'Beg.Stock' ).
          lo_column->set_long_text( 'Beginning Stock' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'BEG_VALUE' ).
          lo_column->set_medium_text( 'Begin Value' ).
          lo_column->set_short_text( 'Beg.Value' ).
          lo_column->set_long_text( 'Beginning Stock Value' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'END_STOCK' ).
          lo_column->set_medium_text( 'End Stock' ).
          lo_column->set_short_text( 'End Stock' ).
          lo_column->set_long_text( 'Ending Stock' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'END_VALUE' ).
          lo_column->set_medium_text( 'End Value' ).
          lo_column->set_short_text( 'End Value' ).
          lo_column->set_long_text( 'Ending Stock Value' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Unit Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'STOCK_WAERS' ).
          lo_column->set_medium_text( 'Curr.' ).
          lo_column->set_short_text( 'Curr' ).
          lo_column->set_long_text( 'Stock Currency' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MEINS' ).
          lo_column->set_medium_text( 'UoM' ).
          lo_column->set_short_text( 'UoM' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Transaction Fields
      TRY.
          lo_column ?= lo_columns->get_column( 'BUDAT_MKPF' ).
          lo_column->set_medium_text( 'Posting Date' ).
          lo_column->set_short_text( 'Post.Date' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'BWART' ).
          lo_column->set_medium_text( 'Mvt Type' ).
          lo_column->set_short_text( 'MvT' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MENGE' ).
          lo_column->set_medium_text( 'Quantity' ).
          lo_column->set_short_text( 'Qty' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MBLNR' ).
          lo_column->set_medium_text( 'Mat. Doc.' ).
          lo_column->set_long_text( 'Material Document' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MJAHR' ).
          lo_column->set_medium_text( 'Year' ).
          lo_column->set_short_text( 'Year' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'DMBTR' ).
          lo_column->set_medium_text( 'Amount' ).
          lo_column->set_short_text( 'Amount' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'WAERS' ).
          lo_column->set_medium_text( 'Curr.' ).
          lo_column->set_short_text( 'Curr' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'SHKZG' ).
          lo_column->set_medium_text( '+/-' ).
          lo_column->set_short_text( '+/-' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'EBELN' ).
          lo_column->set_medium_text( 'PO Number' ).
          lo_column->set_short_text( 'PO' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'EBELP' ).
          lo_column->set_medium_text( 'PO Item' ).
          lo_column->set_short_text( 'Item' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'XBLNR_MKPF' ).
          lo_column->set_medium_text( 'Reference' ).
          lo_column->set_short_text( 'Ref.' ).
          lo_column->set_long_text( 'Reference Document' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Configure totals
      lo_aggregations = lo_alv->get_aggregations( ).
      lo_aggregations->add_aggregation( columnname = 'BEG_STOCK' aggregation = if_salv_c_aggregation=>total ).
      lo_aggregations->add_aggregation( columnname = 'BEG_VALUE' aggregation = if_salv_c_aggregation=>total ).
      lo_aggregations->add_aggregation( columnname = 'END_STOCK' aggregation = if_salv_c_aggregation=>total ).
      lo_aggregations->add_aggregation( columnname = 'END_VALUE' aggregation = if_salv_c_aggregation=>total ).
      lo_aggregations->add_aggregation( columnname = 'MENGE' aggregation = if_salv_c_aggregation=>total ).
      lo_aggregations->add_aggregation( columnname = 'DMBTR' aggregation = if_salv_c_aggregation=>total ).

      " Apply row color coding and tooltips
      PERFORM apply_row_formatting CHANGING lo_alv.

      " Configure layout settings
      lo_layout = lo_alv->get_layout( ).
      ls_key-report = sy-repid.
      lo_layout->set_key( ls_key ).
      lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
      lo_layout->set_default( abap_true ).

      " Display the ALV grid
      lo_alv->display( ).

    CATCH cx_salv_not_found.
      MESSAGE 'ALV column not found. Check field names.' TYPE 'E'.
    CATCH cx_salv_msg.
      MESSAGE 'An error occurred during ALV display.' TYPE 'E'.
    CATCH cx_salv_existing.
      MESSAGE 'Aggregation already exists.' TYPE 'E'.
    CATCH cx_salv_data_error.
      MESSAGE 'ALV data error occurred. Check data structure.' TYPE 'E'.
  ENDTRY.
ENDFORM.

"----------------------------------------------------------------------
" apply_row_formatting
" Purpose: Applies visual enhancements and tooltips to the ALV display
" Parameters: co_alv - ALV grid object (CHANGING)
" Returns: None
" Logic:
"   1. Clear stock/value fields on transaction lines
"   2. Clear transaction fields on placeholder lines
"   3. Add tooltips for:
"      - Movement types (goods receipt, transfer, consumption)
"      - Debit/Credit indicators
"      - Stock types (ROH/FG)
"      - Value calculation method
"----------------------------------------------------------------------
FORM apply_row_formatting CHANGING co_alv TYPE REF TO cl_salv_table.
  DATA: lo_columns     TYPE REF TO cl_salv_columns_table,
        lo_column      TYPE REF TO cl_salv_column_table,
        lv_tooltip     TYPE lvc_tip.

  TRY.
      lo_columns ?= co_alv->get_columns( ).

      " Process display data formatting
      LOOP AT gt_display_data ASSIGNING FIELD-SYMBOL(<fs_display>).
        IF <fs_display>-line_type = 'T'.  " Transaction line
          " Clear stock and value fields on transaction lines
          CLEAR: <fs_display>-beg_stock,
                 <fs_display>-end_stock,
                 <fs_display>-beg_value,
                 <fs_display>-end_value.

          " Clear transaction fields on placeholder line
          IF <fs_display>-maktx = 'No transactions found in period'.
            CLEAR: <fs_display>-budat_mkpf,
                   <fs_display>-bwart,
                   <fs_display>-menge,
                   <fs_display>-mblnr,
                   <fs_display>-mjahr,
                   <fs_display>-dmbtr,
                   <fs_display>-waers,
                   <fs_display>-shkzg,
                   <fs_display>-ebeln,
                   <fs_display>-ebelp,
                   <fs_display>-xblnr_mkpf.
          ENDIF.
        ENDIF.
      ENDLOOP.

      " Add tooltips for movement types
      lo_column ?= lo_columns->get_column( 'BWART' ).
      lv_tooltip = '101=GR, 102=GR Rev, 261=Cons, 262=Cons Rev, ' &&
                   '541=Trf, 542=Trf Rev, 601=Del, 602=Del Rev'.
      lo_column->set_tooltip( lv_tooltip ).

      " Add tooltip for debit/credit indicator
      lo_column ?= lo_columns->get_column( 'SHKZG' ).
      lv_tooltip = 'S=Debit(+), H=Credit(-)'.
      lo_column->set_tooltip( lv_tooltip ).

      " Add tooltip for stock type
      lo_column ?= lo_columns->get_column( 'STOCK_TYPE' ).
      lv_tooltip = 'ROH=Raw Material at Vendor, ' &&
                   'FG=Finished Goods from Subcontracting'.
      lo_column->set_tooltip( lv_tooltip ).

      " Add tooltip for value calculation
      lo_column ?= lo_columns->get_column( 'BEG_VALUE' ).
      lv_tooltip = 'Value = Quantity × (Moving Avg Price ÷ Price Unit)'.
      lo_column->set_tooltip( lv_tooltip ).

      lo_column ?= lo_columns->get_column( 'END_VALUE' ).
      lo_column->set_tooltip( lv_tooltip ).

    CATCH cx_salv_not_found.
      " Ignore if column not found - column settings are optional
  ENDTRY.
ENDFORM.

"-----------------------------------------------------------------------------
" Existing Form: Get Descriptions (remains the same)
"-----------------------------------------------------------------------------
FORM get_descriptions.
  " Same as your original code - no changes needed
  TYPES: BEGIN OF ty_mara_data,
           matnr TYPE mara-matnr,
           meins TYPE mara-meins,
           mtart TYPE mara-mtart,
           matkl TYPE mara-matkl,
         END OF ty_mara_data.

  TYPES: BEGIN OF ty_makt_data,
           matnr TYPE makt-matnr,
           maktx TYPE makt-maktx,
         END OF ty_makt_data.

  TYPES: BEGIN OF ty_t134t_data,
           mtart TYPE t134t-mtart,
           mtbez TYPE t134t-mtbez,
         END OF ty_t134t_data.

  TYPES: BEGIN OF ty_t023t_data,
           matkl TYPE t023t-matkl,
           wgbez TYPE t023t-wgbez,
         END OF ty_t023t_data.

  DATA: lt_mara  TYPE TABLE OF ty_mara_data,
        lt_makt  TYPE TABLE OF ty_makt_data,
        lt_t134t TYPE TABLE OF ty_t134t_data,
        lt_t023t TYPE TABLE OF ty_t023t_data,
        ls_mara  TYPE ty_mara_data,
        ls_makt  TYPE ty_makt_data,
        ls_t134t TYPE ty_t134t_data,
        ls_t023t TYPE ty_t023t_data.

  " Get material master data
  SELECT matnr, meins, mtart, matkl
    FROM mara
    INTO TABLE @lt_mara
    FOR ALL ENTRIES IN @gt_final_data
    WHERE matnr = @gt_final_data-matnr.

  " Get material descriptions
  SELECT matnr, maktx
    FROM makt
    INTO TABLE @lt_makt
    FOR ALL ENTRIES IN @gt_final_data
    WHERE matnr = @gt_final_data-matnr
      AND spras = 'E'.

  " Get material type descriptions
  SELECT mtart, mtbez
    FROM t134t
    INTO TABLE @lt_t134t
    FOR ALL ENTRIES IN @lt_mara
    WHERE mtart = @lt_mara-mtart
      AND spras = 'E'.

  " Get material group descriptions
  SELECT matkl, wgbez
    FROM t023t
    INTO TABLE @lt_t023t
    FOR ALL ENTRIES IN @lt_mara
    WHERE matkl = @lt_mara-matkl
      AND spras = 'E'.

  " Update final data with descriptions
  LOOP AT gt_final_data ASSIGNING FIELD-SYMBOL(<fs_final>).
    " Material master data
    READ TABLE lt_mara INTO ls_mara
      WITH KEY matnr = <fs_final>-matnr.
    IF sy-subrc = 0.
      <fs_final>-meins = ls_mara-meins.
      <fs_final>-mtart = ls_mara-mtart.
      <fs_final>-matkl = ls_mara-matkl.

      " Material type description
      READ TABLE lt_t134t INTO ls_t134t
        WITH KEY mtart = ls_mara-mtart.
      IF sy-subrc = 0.
        <fs_final>-mtbez = ls_t134t-mtbez.
      ENDIF.

      " Material group description
      READ TABLE lt_t023t INTO ls_t023t
        WITH KEY matkl = ls_mara-matkl.
      IF sy-subrc = 0.
        <fs_final>-wgbez = ls_t023t-wgbez.
      ENDIF.
    ENDIF.

    " Material description
    READ TABLE lt_makt INTO ls_makt
      WITH KEY matnr = <fs_final>-matnr.
    IF sy-subrc = 0.
      <fs_final>-maktx = ls_makt-maktx.
    ENDIF.
  ENDLOOP.
ENDFORM.

"-----------------------------------------------------------------------------
" Existing Form: Get Master Material List (for ROH - remains the same)
"-----------------------------------------------------------------------------
FORM get_master_material_list.
  DATA: lv_year   TYPE lfgja,
        lv_period TYPE lfmon.

  " Get materials from beginning period (previous period)
  SELECT matnr, lifnr
    FROM mslbh
    INTO TABLE @gt_master_materials
    WHERE matnr IN @s_matnr
      AND lifnr IN @s_lifnr
      AND lfgja = @gv_beg_year
      AND lfmon = @gv_beg_period
      AND lblab > 0.

  " Get materials from the entire selection range
  lv_year = p_fryr.
  lv_period = p_frper.

  WHILE lv_year < p_toyr OR ( lv_year = p_toyr AND lv_period <= p_toper ).
    SELECT matnr, lifnr
      FROM mslbh
      APPENDING TABLE @gt_master_materials
      WHERE matnr IN @s_matnr
        AND lifnr IN @s_lifnr
        AND lfgja = @lv_year
        AND lfmon = @lv_period
        AND lblab > 0.

    " Move to next period
    lv_period = lv_period + 1.
    IF lv_period > 12.
      lv_period = 1.
      lv_year = lv_year + 1.
    ENDIF.
  ENDWHILE.

  " If ending period is current period, also get from MSLB
  IF gv_use_mslb_for_end = abap_true.
    SELECT matnr, lifnr
      FROM mslb
      APPENDING TABLE @gt_master_materials
      WHERE matnr IN @s_matnr
        AND lifnr IN @s_lifnr
        AND lfgja = @p_toyr
        AND lfmon = @p_toper
        AND lblab > 0.
  ENDIF.

  " Remove duplicates
  SORT gt_master_materials BY matnr lifnr.
  DELETE ADJACENT DUPLICATES FROM gt_master_materials.

  "WRITE: / 'Found', lines( gt_master_materials ), 'unique ROH materials with special stock.'.
ENDFORM.
