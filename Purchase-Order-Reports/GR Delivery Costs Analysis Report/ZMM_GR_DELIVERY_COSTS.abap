*&---------------------------------------------------------------------*
*& SAP Subcontractor Stock Report with Values Report
*& Copyright (c) 2025 [Mohammed Abbas]
*& Licensed under CC BY-NC-SA 4.0
*& Built with AI assistance to democratize SAP reporting
*&---------------------------------------------------------------------*

REPORT zmm_gr_delivery_costs.

*&---------------------------------------------------------------------*
*& Purpose: Analyze and report on goods receipt delivery costs
*& - Tracks both goods receipt postings and associated conditions
*& - Handles local and document currency amounts
*& - Processes various cost conditions (freight, customs, etc.)
*& - Provides ALV output with subtotals and aggregations
*&---------------------------------------------------------------------*
*& Processing Logic:
*& 1. Fetch goods receipt documents (EKBE) for selected POs
*& 2. Get associated condition records (EKBZ)
*& 3. Enrich with material, incoterm, and payment term info
*& 4. Display in ALV with grouping and subtotals
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& Database Tables
*&---------------------------------------------------------------------*
TABLES: ekbz,    " Purchase Order History (Conditions)
        ekko,    " Purchase Order Header
        tvzb,    " Payment Terms
        tvzbt.   " Payment Terms Text

*&---------------------------------------------------------------------*
*& Selection Screen: Allows filtering by PO number and posting date
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE TEXT-001.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(20) comm1.
    SELECTION-SCREEN POSITION 25.
    SELECT-OPTIONS: s_ebeln FOR ekbz-ebeln.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(20) comm2.
    SELECTION-SCREEN POSITION 25.
    SELECT-OPTIONS: s_budat FOR ekbz-budat OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK blk1.

"-----------------------------------------------------------------------------
" Initialization
"-----------------------------------------------------------------------------
INITIALIZATION.
  comm1 = 'Purchase order'.
  comm2 = 'Posting date'.

"-----------------------------------------------------------------------------
*& Type Definitions
*&---------------------------------------------------------------------*
*& Structure ty_final: Main data structure for report output
*& - Contains both GR and condition data
*& - Includes material master, incoterms, and payment term info
*& - Handles both local and document currency amounts
*&---------------------------------------------------------------------*
TYPES: BEGIN OF ty_final,
         ebeln          TYPE ebeln,         " Purchase order number
         ebelp          TYPE ebelp,         " Purchase order item
         belnr          TYPE belnr_d,       " Material document/invoice number
         gjahr          TYPE gjahr,         " Fiscal year of document
         budat          TYPE budat,         " Posting date of document

         menge          TYPE menge_d,       " Quantity in purchase order unit

         " Local currency amounts (e.g. EGP)
         amount_local   TYPE dmbtr,         " Amount in local currency
         waers_local    TYPE waers,         " Local currency key

         " Document currency amounts (from PO/invoice)
         amount_doc     TYPE wrbtr,         " Amount in document currency
         waers_doc      TYPE waers,         " Document currency key

         line_type      TYPE char4,         " Record type: 'GR' or 'COND'
         condition_type TYPE kschl,         " Condition type (e.g. freight, customs)
         condition_name TYPE char60,        " Description of condition in local language

         " Purchase order terms
         incoterms      TYPE inco1,         " Incoterms (e.g. FOB, CIF)
         incoterms_loc  TYPE inco2_l,       " Incoterms location/city
         zterm          TYPE ekko-zterm,    " Payment terms key
         zterm_desc     TYPE tvzbt-vtext,   " Payment terms description

         " Material information
         matnr          TYPE matnr,         " Material number
         matdesc        TYPE makt-maktg,    " Material description
         mtart          TYPE mara-mtart,    " Material type (e.g. ROH, FERT)
         mtbez          TYPE t134t-mtbez,   " Material type description
         matkl          TYPE mara-matkl,    " Material group
         wgbez          TYPE t023t-wgbez,   " Material group description
         xblnr          TYPE rbkp-xblnr,    " Reference document (invoice number)
       END OF ty_final.

*&---------------------------------------------------------------------*
*& Global Data Declarations
*&---------------------------------------------------------------------*
DATA: lt_final TYPE STANDARD TABLE OF ty_final,  " Main output table
      ls_final TYPE ty_final.                    " Work area for output

"-----------------------------------------------------------------------------
*& Main Processing Logic
*&---------------------------------------------------------------------*
START-OF-SELECTION.

*&---------------------------------------------------------------------*
*& Step 1: Process Goods Receipt Data
*& - Reads material documents (EKBE) for goods receipts
*& - Only processes movement type 'Q' (goods receipt)
*& - Calculates amounts in both local and document currency
*& - Enriches with PO terms and material master data
*&---------------------------------------------------------------------*
  DATA: lt_ekbe TYPE TABLE OF ekbe.

  SELECT *
    FROM ekbe
    INTO TABLE @lt_ekbe
    WHERE ebeln IN @s_ebeln
      AND bewtp = 'Q'   " Q = Goods Receipt movement type
      AND budat IN @s_budat.

  LOOP AT lt_ekbe INTO DATA(ls_ekbe).
    CLEAR ls_final.

    " Copy document header data
    ls_final-ebeln = ls_ekbe-ebeln.
    ls_final-ebelp = ls_ekbe-ebelp.
    ls_final-belnr = ls_ekbe-belnr.
    ls_final-gjahr = ls_ekbe-gjahr.
    ls_final-budat = ls_ekbe-budat.
    ls_final-menge = ls_ekbe-menge.

    " Handle currency amounts
    ls_final-amount_local = ls_ekbe-dmbtr.    " Local currency amount
    ls_final-waers_local = 'EGP'.             " TODO: Make configurable
    ls_final-amount_doc = ls_ekbe-wrbtr.      " Document currency amount
    ls_final-waers_doc  = ls_ekbe-waers.      " Document currency key

    ls_final-line_type = 'GR'.                " Mark as goods receipt line

    " Get PO header data (incoterms, payment terms)
    SELECT SINGLE inco1, inco2_l, zterm
      FROM ekko
      INTO ( @ls_final-incoterms,
             @ls_final-incoterms_loc,
             @ls_final-zterm )
      WHERE ebeln = @ls_ekbe-ebeln.

    " Get payment terms description if available
    IF sy-subrc = 0 AND ls_final-zterm IS NOT INITIAL.
      SELECT SINGLE vtext
        FROM tvzbt
        INTO @ls_final-zterm_desc
        WHERE zterm = @ls_final-zterm
          AND spras = @sy-langu.
    ENDIF.

    " Get material master data
    PERFORM fill_material_info USING ls_final-ebeln
                                    ls_final-ebelp
                             CHANGING ls_final.

    APPEND ls_final TO lt_final.
  ENDLOOP.

*&---------------------------------------------------------------------*
*& Step 2: Process Condition Records
*& - Reads condition records (EKBZ) for additional costs
*& - Handles both debit (S) and credit (H) postings
*& - Processes movement types 2 and 3 (invoice-related)
*& - Maps condition types to descriptions
*& - Enriches with PO terms and material master data
*&---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_ekbz_rows,
           ebeln TYPE ekbz-ebeln,            " Purchase order
           ebelp TYPE ekbz-ebelp,            " Item number
           belnr TYPE ekbz-belnr,            " Invoice document
           gjahr TYPE gjahr,                 " Fiscal year
           shkzg TYPE ekbz-shkzg,            " Debit/Credit indicator
           dmbtr TYPE ekbz-dmbtr,            " Amount in local currency
           wrbtr TYPE ekbz-wrbtr,            " Amount in document currency
           waers TYPE ekbz-waers,            " Currency key
           kschl TYPE ekbz-kschl,            " Condition type
           vgabe TYPE ekbz-vgabe,            " Transaction/movement type
           menge TYPE ekbz-menge,            " Quantity
           budat TYPE budat,                 " Posting date
         END OF ty_ekbz_rows.

  DATA: lt_ekbz_rows TYPE STANDARD TABLE OF ty_ekbz_rows.

  " Select condition records for invoice-related movements
  SELECT ebeln,
         ebelp,
         belnr,
         gjahr,
         shkzg,
         dmbtr,
         wrbtr,
         waers,
         kschl,
         vgabe,
         menge,
         budat
    FROM ekbz
    INTO TABLE @lt_ekbz_rows
    WHERE ebeln IN @s_ebeln
      AND vgabe IN ( '2', '3' )    " Invoice-related movements only
      AND budat IN @s_budat.

  LOOP AT lt_ekbz_rows INTO DATA(ls_cond).
    CLEAR ls_final.

    " Copy document header data
    ls_final-ebeln = ls_cond-ebeln.
    ls_final-ebelp = ls_cond-ebelp.
    ls_final-belnr = ls_cond-belnr.
    ls_final-gjahr = ls_cond-gjahr.
    ls_final-budat = ls_cond-budat.

    ls_final-line_type = 'COND'.    " Mark as condition record

    " Handle debit/credit indicator
    " H = Credit (negative amount), S = Debit (positive amount)
    IF ls_cond-shkzg = 'H'.
      ls_final-amount_local = -1 * ls_cond-dmbtr.
      ls_final-amount_doc   = -1 * ls_cond-wrbtr.
      ls_final-menge        = -1 * ls_cond-menge.
    ELSE.
      ls_final-amount_local = ls_cond-dmbtr.
      ls_final-amount_doc   = ls_cond-wrbtr.
      ls_final-menge        = ls_cond-menge.
    ENDIF.

    " Set currency information
    ls_final-waers_local = 'EGP'.             " TODO: Make configurable
    ls_final-waers_doc   = ls_cond-waers.

    " Get condition type and description
    ls_final-condition_type = ls_cond-kschl.
    PERFORM map_condition_name USING ls_cond-kschl
                             CHANGING ls_final-condition_name.

    " Get PO header data (incoterms, payment terms)
    SELECT SINGLE inco1, inco2_l, zterm
      FROM ekko
      INTO ( @ls_final-incoterms,
             @ls_final-incoterms_loc,
             @ls_final-zterm )
      WHERE ebeln = @ls_cond-ebeln.

    " Get payment terms description if available
    IF sy-subrc = 0 AND ls_final-zterm IS NOT INITIAL.
      SELECT SINGLE vtext
        FROM tvzbt
        INTO @ls_final-zterm_desc
        WHERE zterm = @ls_final-zterm
          AND spras = @sy-langu.
    ENDIF.

    " Get material master data
    PERFORM fill_material_info USING ls_final-ebeln
                                    ls_final-ebelp
                             CHANGING ls_final.

    " Get invoice reference number
    SELECT SINGLE xblnr
      FROM rbkp
      INTO @ls_final-xblnr
      WHERE belnr = @ls_cond-belnr
        AND gjahr = @ls_cond-gjahr.

    APPEND ls_final TO lt_final.
  ENDLOOP.

  " Display final ALV report
  PERFORM display_alv USING lt_final.

*&---------------------------------------------------------------------*
*& Form map_condition_name
*&---------------------------------------------------------------------*
*& Maps condition types to their descriptions in local language
*&---------------------------------------------------------------------*
*& -->  p1        Condition type (KSCHL)
*& <--  p2        Condition description
*&---------------------------------------------------------------------*
FORM map_condition_name USING iv_kschl TYPE kschl
                          CHANGING cv_text TYPE char60.
  CASE iv_kschl.
    WHEN 'ZADS'.  cv_text = 'مصاريف اضافية'.      " Additional expenses
    WHEN 'ZBNK'.  cv_text = 'مصاريف بنكية'.       " Bank charges
    WHEN 'ZBNP'.  cv_text = 'مصاريف بنكية %'.     " Bank charges %
    WHEN 'ZCLE'.  cv_text = 'مصاريف تخليص'.       " Clearance fees
    WHEN 'ZCUM'.  cv_text = 'مرسوم النافذة الجمرك'. " Customs window fees
    WHEN 'ZDIF'.  cv_text = 'ضريبة الوارد %'.      " Import tax %
    WHEN 'ZFRE'.  cv_text = 'Freight'.            " Freight charges
    WHEN 'ZFRG'.  cv_text = 'FOB Charge / FCA'.   " FOB/FCA charges
    WHEN 'ZINS'.  cv_text = 'Insurance'.          " Insurance (fixed)
    WHEN 'ZINU'.  cv_text = 'Insurance %'.        " Insurance (percentage)
    WHEN 'ZOB1'.  cv_text = 'Customs (Value)'.    " Customs duty
    WHEN 'ZPAK'.  cv_text = 'مصاريف تعبئة'.        " Packing expenses
    WHEN 'ZSMP'.  cv_text = 'دمغة علمية'.          " Scientific stamp
    WHEN 'ZSTE'.  cv_text = 'مصروف تخزين'.         " Storage expenses
    WHEN 'ZTR1'.  cv_text = 'مصاريف نقل'.          " Transport expenses
    WHEN 'ZUNL'.  cv_text = 'مصاريف تفريغ'.        " Unloading expenses
    WHEN 'ZVAT'.  cv_text = 'VAT'.                " Value Added Tax
    WHEN OTHERS.
      cv_text = iv_kschl.
  ENDCASE.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form fill_material_info
*&---------------------------------------------------------------------*
*& Retrieves and fills material master data:
*& - Material number from purchase order item
*& - Material type and group from material master
*& - Material descriptions from various text tables
*&---------------------------------------------------------------------*
*& -->  p1        Purchase order number
*& -->  p2        Purchase order item
*& <--  p3        Structure to fill with material data
*&---------------------------------------------------------------------*
FORM fill_material_info USING iv_ebeln TYPE ebeln
                             iv_ebelp TYPE ebelp
                     CHANGING cs_final TYPE ty_final.

  " Get material number from PO item
  DATA ls_ekpo TYPE ekpo.
  SELECT SINGLE matnr
    FROM ekpo
    INTO @ls_ekpo-matnr
    WHERE ebeln = @iv_ebeln
      AND ebelp = @iv_ebelp.

  IF sy-subrc <> 0 OR ls_ekpo-matnr IS INITIAL.
    RETURN.
  ENDIF.

  cs_final-matnr = ls_ekpo-matnr.

  " Get material type and group
  DATA ls_mara TYPE mara.
  SELECT SINGLE mtart, matkl
    FROM mara
    INTO ( @ls_mara-mtart, @ls_mara-matkl )
    WHERE matnr = @ls_ekpo-matnr.

  IF sy-subrc = 0.
    cs_final-mtart = ls_mara-mtart.
    cs_final-matkl = ls_mara-matkl.
  ENDIF.

  " Get material type description
  SELECT SINGLE mtbez
    FROM t134t
    INTO @cs_final-mtbez
    WHERE spras = 'EN'
      AND mtart = @ls_mara-mtart.

  " Get material group description
  SELECT SINGLE wgbez
    FROM t023t
    INTO @cs_final-wgbez
    WHERE spras = 'EN'
      AND matkl = @ls_mara-matkl.

  " Get material description
  SELECT SINGLE maktg
    FROM makt
    INTO @cs_final-matdesc
    WHERE matnr = @ls_ekpo-matnr
      AND spras = 'EN'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& Displays the final ALV grid with:
*& - Standard ALV functionality enabled
*& - Layout saving/loading capability
*& - Aggregations for amounts and quantities
*& - Grouping by PO, currency, condition
*& - Optimized column widths
*& - Currency reference fields properly set
*&---------------------------------------------------------------------*
*& -->  p1        Internal table with data to display
*&---------------------------------------------------------------------*
FORM display_alv USING pt_data TYPE STANDARD TABLE.

  DATA lo_alv TYPE REF TO cl_salv_table.

  TRY.
      " Create ALV grid instance
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = pt_data
      ).

      " Enable all standard ALV functions (filters, sort, etc.)
      lo_alv->get_functions( )->set_all( abap_true ).

      " Configure layout settings
      DATA(lo_layout) = lo_alv->get_layout( ).
      DATA(ls_layout_key) = VALUE salv_s_layout_key(
        report = sy-repid                    " Current program
        handle = 'ZMM_GR_COSTS_LAYOUT'       " Unique layout handle
      ).
      lo_layout->set_key( ls_layout_key ).
      lo_layout->set_default( abap_true ).                     " Set as default layout
      lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).  " Allow saving

      " Set up amount aggregations
      DATA(lo_aggs) = lo_alv->get_aggregations( ).
      lo_aggs->add_aggregation( 'MENGE' ).         " Sum quantities
      lo_aggs->add_aggregation( 'AMOUNT_LOCAL' ).  " Sum local amounts
      lo_aggs->add_aggregation( 'AMOUNT_DOC' ).    " Sum document amounts

      " Configure sorting and subtotals
      DATA(lo_sorts) = lo_alv->get_sorts( ).
      lo_sorts->clear( ).

      " Define sort hierarchy with subtotals:
      " 1. Purchase Order (main grouping)
      lo_sorts->add_sort( 'EBELN' )->set_subtotal( abap_true ).
      " 2. Document Currency (separate totals per currency)
      lo_sorts->add_sort( 'WAERS_DOC' )->set_subtotal( abap_true ).
      " 3. Condition Type (group charges together)
      lo_sorts->add_sort( 'CONDITION_NAME' )->set_subtotal( abap_true ).
      " 4. Item Number (lowest level)
      lo_sorts->add_sort( 'EBELP' )->set_subtotal( abap_true ).

      " Optimize column widths
      lo_alv->get_columns( )->set_optimize( abap_true ).

      " Get column object reference
      DATA(lo_columns) = lo_alv->get_columns( ).

      " Configure currency reference fields
      " This ensures proper currency display and calculations
      DATA(lo_col_local) = lo_columns->get_column( 'AMOUNT_LOCAL' ).
      lo_col_local->set_currency_column( 'WAERS_LOCAL' ).

      DATA(lo_col_doc) = lo_columns->get_column( 'AMOUNT_DOC' ).
      lo_col_doc->set_currency_column( 'WAERS_DOC' ).

      " Set user-friendly column headers
      DATA(lo_column_cond_name) = lo_columns->get_column( 'CONDITION_NAME' ).
      lo_column_cond_name->set_long_text( 'Condition Type Name' ).
      lo_column_cond_name->set_medium_text( 'Cond. Type Name' ).
      lo_column_cond_name->set_short_text( 'Cond. Name' ).

      lo_col_local->set_long_text( 'Local Amount' ).
      lo_col_doc->set_long_text( 'Document Amount' ).

      " Display the ALV grid
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.
ENDFORM.
