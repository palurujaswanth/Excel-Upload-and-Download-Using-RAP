@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parent Consumption view'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_USER_P
  as projection on zi_user_pc
{
  key EmpId,
  key DevId,
      DevDescription,

      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'Filename',
        acceptableMimeTypes: [
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ],
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,

      @Semantics.mimeType: true
      Mimetype,
      Filename,
      FileStatus,
      Criticality,
      TemplateStatus,
      TemplateCrticality,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _UserDev : redirected to composition child ZC_USER_C
}
