@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Child Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_user_c
  as select from ztdb_user_child
  association to parent zi_user_pc as _User on  $projection.EmpId = _User.EmpId
                                              and $projection.DevId = _User.DevId
{
  key emp_id      as EmpId,
  key dev_id      as DevId,
  key serial_no   as SerialNo,
      object_type as ObjectType,
      object_name as ObjectName,
      _User
}
