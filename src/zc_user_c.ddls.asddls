@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Child Consumption View'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_USER_C
  as projection on ZI_user_c
{
  key EmpId,
  key DevId,
  key SerialNo,
      ObjectType,
      ObjectName,

      /* Associations */
      _User : redirected to parent ZC_USER_P
}
