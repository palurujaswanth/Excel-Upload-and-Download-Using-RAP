CLASS lhc_User DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR User RESULT result.

   " METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
    "  IMPORTING REQUEST requested_authorizations FOR User RESULT result.

    METHODS uploadExcelData FOR MODIFY
      IMPORTING keys FOR ACTION User~uploadExcelData RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR User RESULT result.

    METHODS fillselectedstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR user~fillselectedstatus.

    METHODS fillfilestatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR user~fillfilestatus.

    METHODS downloadexcel FOR MODIFY
      IMPORTING keys FOR ACTION user~downloadexcel RESULT result.

ENDCLASS.

CLASS lhc_User IMPLEMENTATION.

  METHOD DownloadExcel.
    DATA: lt_template TYPE STANDARD TABLE OF zbp_i_user_pc=>gty_exl_file.

    DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_worksheet)    = lo_write_access->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    lt_template = VALUE #( (
      emp_id   = 'User Id'
      dev_id   = 'Development Id'
      dev_desc = 'Development Description'
      obj_type = 'Object Type'
      obj_name = 'Object Name'
    ) ).

    lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_from( REF #( lt_template )
      )->execute( ).

    DATA(lv_file_content) = lo_write_access->get_file_content( ).

    "Modify Root Entity with generated Excel template
    MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      UPDATE FROM VALUE #( FOR ls_key IN keys (
        EmpId               = ls_key-EmpId
        DevId               = ls_key-DevId
        Attachment          = lv_file_content
        Filename            = 'template.xlsx'
        Mimetype            = 'application/vnd.ms-excel'
        %control-Attachment = if_abap_behv=>mk-on
        %control-Filename   = if_abap_behv=>mk-on
        %control-Mimetype   = if_abap_behv=>mk-on
      ) )
      FAILED   DATA(ls_failed_update)
      MAPPED   DATA(ls_mapped_update)
      REPORTED DATA(ls_reported_update).

    "Read Updated Entry
    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_User).

    "Update File and Template Status
    LOOP AT lt_User INTO DATA(ls_user).
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        UPDATE FIELDS ( FileStatus TemplateStatus )
        WITH VALUE #( (
          %tky                    = ls_user-%tky
          %data-FileStatus        = 'File not Selected'
          %data-TemplateStatus    = 'Present'
          %control-FileStatus     = if_abap_behv=>mk-on
          %control-TemplateStatus = if_abap_behv=>mk-on
        ) )
        MAPPED   DATA(ls_mapped_status)
        REPORTED DATA(ls_reported_status)
        FAILED   DATA(ls_failed_status).
    ENDLOOP.

    "Send Status back to front end
    result = VALUE #( FOR ls_upd_user IN lt_User (
      %tky   = ls_upd_user-%tky
      %param = ls_upd_user
    ) ).

    IF ls_failed_update IS INITIAL.
      reported-user = VALUE #( BASE reported-user (
        %tky = keys[ 1 ]-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = 'Template Available.'
               )
      ) ).
    ENDIF.
  ENDMETHOD.

  METHOD uploadExcelData.
    DATA: lt_rows         TYPE STANDARD TABLE OF string,
          lv_content      TYPE string,
          lo_table_descr  TYPE REF TO cl_abap_tabledescr,
          lo_struct_descr TYPE REF TO cl_abap_structdescr,
          lt_excel        TYPE STANDARD TABLE OF zbp_i_user_pc=>gty_exl_file,
          lt_excel_temp   TYPE STANDARD TABLE OF zbp_i_user_pc=>gty_exl_file,
          lt_excel_filter TYPE SORTED TABLE OF zbp_i_user_pc=>gty_exl_file WITH UNIQUE KEY emp_id dev_id,
          lt_data         TYPE TABLE FOR CREATE zi_user_pc\_UserDev,
          lv_index        TYPE sy-index.

    FIELD-SYMBOLS: <lfs_col_header> TYPE string.

    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity).

    DATA(lv_attachment) = lt_file_entity[ 1 ]-Attachment.
    CHECK lv_attachment IS NOT INITIAL.

    "Move Excel Data to Internal Table
    DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = lv_attachment )->read_access( ).
    DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    "Explicitly set boundaries from A1 across columns A to E
    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    DATA(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_excel_temp ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    "Get number of columns for validation
    TRY.
        lo_table_descr ?= cl_abap_tabledescr=>describe_by_data( p_data = lt_excel_temp ).
        lo_struct_descr ?= lo_table_descr->get_table_line_type( ).
        DATA(lv_no_of_cols) = lines( lo_struct_descr->components ).
      CATCH cx_sy_move_cast_error.
    ENDTRY.

    "Validate Header record
    DATA(ls_excel) = VALUE #( lt_excel_temp[ 1 ] OPTIONAL ).
    DATA: lv_has_error TYPE abap_bool VALUE abap_false.

    IF ls_excel IS NOT INITIAL.
      DO lv_no_of_cols TIMES.
        lv_index = sy-index.
        ASSIGN COMPONENT lv_index OF STRUCTURE ls_excel TO <lfs_col_header>.
        CHECK <lfs_col_header> IS ASSIGNED.
        DATA(lv_value) = to_upper( <lfs_col_header> ).

        CASE lv_index.
          WHEN 1.
            lv_has_error = COND #( WHEN lv_value <> 'USER ID' THEN abap_true ELSE lv_has_error ).
          WHEN 2.
            lv_has_error = COND #( WHEN lv_value <> 'DEVELOPMENT ID' THEN abap_true ELSE lv_has_error ).
          WHEN 3.
            lv_has_error = COND #( WHEN lv_value <> 'DEVELOPMENT DESCRIPTION' THEN abap_true ELSE lv_has_error ).
          WHEN 4.
            lv_has_error = COND #( WHEN lv_value <> 'OBJECT TYPE' THEN abap_true ELSE lv_has_error ).
          WHEN 5.
            lv_has_error = COND #( WHEN lv_value <> 'OBJECT NAME' THEN abap_true ELSE lv_has_error ).
          WHEN 6. "serial_no component in the structure
            "Skip check if column 6 header in excel is initial/blank
            IF lv_value IS NOT INITIAL.
              lv_has_error = abap_true.
            ENDIF.
          WHEN OTHERS.
            lv_has_error = abap_true.
        ENDCASE.

        IF lv_has_error = abap_true.
          APPEND VALUE #( %tky = lt_file_entity[ 1 ]-%tky ) TO failed-user.
          APPEND VALUE #(
            %tky = lt_file_entity[ 1 ]-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = 'One or more heading is incorrect!!'
                   )
          ) TO reported-user.
          UNASSIGN <lfs_col_header>.
          EXIT.
        ENDIF.
        UNASSIGN <lfs_col_header>.
      ENDDO.
    ENDIF.

    CHECK lv_has_error = abap_false.

"Remove Header Row
    DELETE lt_excel_temp INDEX 1.

    "Clean up and normalize Screen Keys
    DATA(lv_target_emp) = to_upper( condense( CONV string( keys[ 1 ]-EmpId ) ) ).
    DATA(lv_target_dev) = to_upper( condense( CONV string( keys[ 1 ]-DevId ) ) ).
    SHIFT lv_target_emp LEFT DELETING LEADING '0'.

    CLEAR lt_excel.

    "Match Excel rows against Screen Keys (ignoring leading zeros and spaces)
    LOOP AT lt_excel_temp INTO DATA(ls_file_row).
      DATA(lv_row_emp) = to_upper( condense( ls_file_row-emp_id ) ).
      DATA(lv_row_dev) = to_upper( condense( ls_file_row-dev_id ) ).
      SHIFT lv_row_emp LEFT DELETING LEADING '0'.

      IF lv_row_emp = lv_target_emp AND lv_row_dev = lv_target_dev AND ls_file_row-obj_name IS NOT INITIAL.
        APPEND ls_file_row TO lt_excel.
      ENDIF.
    ENDLOOP.
    IF lt_excel IS INITIAL.
      reported-user = VALUE #( BASE reported-user (
        %tky = keys[ 1 ]-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = 'Trying to insert Invalid /Blank Values.'
               )
      ) ).
    ELSE.
      LOOP AT lt_excel ASSIGNING FIELD-SYMBOL(<lfs_excel>).
        <lfs_excel>-serial_no = sy-tabix.
      ENDLOOP.

      "Prepare Data for Child Entity
      lt_data = VALUE #( (
        %cid_ref = keys[ 1 ]-%cid_ref
        EmpId    = keys[ 1 ]-EmpId
        DevId    = keys[ 1 ]-DevId
        %target  = VALUE #( FOR lwa_excel IN lt_excel (
          %cid       = keys[ 1 ]-%cid_ref
          EmpId      = keys[ 1 ]-EmpId
          DevId      = keys[ 1 ]-DevId
          SerialNo   = lwa_excel-serial_no
          ObjectType = lwa_excel-obj_type
          ObjectName = lwa_excel-obj_name
          %control   = VALUE #(
            EmpId      = if_abap_behv=>mk-on
            DevId      = if_abap_behv=>mk-on
            SerialNo   = if_abap_behv=>mk-on
            ObjectType = if_abap_behv=>mk-on
            ObjectName = if_abap_behv=>mk-on
          )
        ) )
      ) ).

      "Delete Existing entries for user if any
      READ ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User BY \_UserDev
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_existing_UserDev).

      IF lt_existing_UserDev IS NOT INITIAL.
        MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
          ENTITY UserDev
          DELETE FROM VALUE #( FOR lwa_data IN lt_existing_UserDev ( %key = lwa_data-%key ) )
          MAPPED   DATA(lt_del_mapped)
          REPORTED DATA(lt_del_reported)
          FAILED   DATA(lt_del_failed).
      ENDIF.

      "Add New Entry for UserDev via association
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        CREATE BY \_UserDev
        AUTO FILL CID WITH lt_data.

      "Modify File Status
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        UPDATE FROM VALUE #( (
          %tky                = lt_file_entity[ 1 ]-%tky
          FileStatus          = 'Excel Uploaded'
          %control-FileStatus = if_abap_behv=>mk-on
        ) )
        MAPPED   DATA(lt_upd_mapped)
        FAILED   DATA(lt_upd_failed)
        REPORTED DATA(lt_upd_reported).

      "Read Updated Entry
      READ ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_updated_User).

      "Send Status back to frontend
      result = VALUE #( FOR lwa_upd_head IN lt_updated_User (
        %tky   = lwa_upd_head-%tky
        %param = lwa_upd_head
      ) ).

      IF lt_upd_failed IS INITIAL.
        reported-user = VALUE #( BASE reported-user (
          %tky = keys[ 1 ]-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = 'Excel Uploaded Successfully.'
                 )
        ) ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD FillFileStatus.
    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      FIELDS ( EmpId DevId FileStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    LOOP AT lt_user INTO DATA(ls_user).
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        UPDATE FIELDS ( FileStatus TemplateStatus )
        WITH VALUE #( (
          %tky                    = ls_user-%tky
          %data-FileStatus        = 'File not Selected'
          %data-TemplateStatus    = 'Absent'
          %control-FileStatus     = if_abap_behv=>mk-on
          %control-TemplateStatus = if_abap_behv=>mk-on
        ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD FillSelectedStatus.
    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    LOOP AT lt_user INTO DATA(ls_user).
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        UPDATE FIELDS ( FileStatus )
        WITH VALUE #( (
          %tky                = ls_user-%tky
          %data-FileStatus    = COND #( WHEN ls_user-Attachment IS INITIAL
                                        THEN 'File not Selected'
                                        ELSE 'File Selected' )
          %control-FileStatus = if_abap_behv=>mk-on
        ) ).
    ENDLOOP.

    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user_updated).

    LOOP AT lt_user_updated INTO DATA(ls_user_updated).
      MODIFY ENTITIES OF zi_user_pc IN LOCAL MODE
        ENTITY User
        UPDATE FIELDS ( TemplateStatus )
        WITH VALUE #( (
          %tky                    = ls_user_updated-%tky
          %data-TemplateStatus    = COND #( WHEN ls_user_updated-Attachment IS NOT INITIAL
                                            THEN COND #( WHEN ls_user_updated-FileStatus = 'File Selected'
                                                         THEN 'Present'
                                                         ELSE 'Absent' )
                                            ELSE 'Absent' )
          %control-TemplateStatus = if_abap_behv=>mk-on
        ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_user_pc IN LOCAL MODE
      ENTITY User
      FIELDS ( EmpId DevId FileStatus TemplateStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_users)
      FAILED failed.

    result = VALUE #( FOR user IN lt_users
      LET uploadbtn        = COND #( WHEN user-FileStatus = 'File Selected'
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )
          downloadtemplate = COND #( WHEN user-TemplateStatus = 'Absent'
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )
      IN (
        %tky                    = user-%tky
        %assoc-_UserDev         = if_abap_behv=>fc-o-disabled
        %action-uploadExcelData = uploadbtn
        %action-DownloadExcel   = downloadtemplate
      ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

 " METHOD get_global_authorizations.
  "ENDMETHOD.

ENDCLASS.
