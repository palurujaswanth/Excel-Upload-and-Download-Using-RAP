CLASS zbp_i_user_pc DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_user_pc.
  PUBLIC SECTION.
    TYPES: BEGIN OF gty_exl_file,
             emp_id    TYPE string,
             dev_id    TYPE string,
             dev_desc  TYPE string,
             obj_type  TYPE string,
             obj_name  TYPE string,
             serial_no TYPE string,
           END OF gty_exl_file.
ENDCLASS.

CLASS zbp_i_user_pc IMPLEMENTATION.
ENDCLASS.
