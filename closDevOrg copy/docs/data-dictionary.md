# LOS data dictionary — through Task 02

API names are unnamespaced source names. Standard Name and OwnerId are not included in custom-field counts. All nine core objects have Private internal/external OWD. Runtime guards control application, history and TAT writes. See [runtime architecture](task-02-runtime.md).

## LOS_Application_Type__mdt

Extensible application types. No compiled product-specific enum.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Sequence__c | Number | No |  |
| LOS_Baseline_Required__c | Checkbox | No |  |
| LOS_Initial_Stage__c | MetadataRelationship | No | LOS_Stage__mdt |

Validation rules: None.

## LOS_Stage__mdt

Configurable lifecycle stages shared by application types. Rework is a transition, never a stage.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Sequence__c | Number | No |  |
| LOS_Display_Label__c | Text | Yes |  |
| LOS_Terminal_Stage__c | Checkbox | No |  |
| LOS_TAT_Enabled__c | Checkbox | No |  |
| LOS_Approval_Stage__c | Checkbox | No |  |
| LOS_Documentation_Stage__c | Checkbox | No |  |
| LOS_Booking_Stage__c | Checkbox | No |  |

Validation rules: None.

## LOS_Stage_Transition__mdt

Allowed directed lifecycle edges; optional application-type scope. Specific scope overrides global scope by transition code.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_From_Stage__c | MetadataRelationship | Yes | LOS_Stage__mdt |
| LOS_To_Stage__c | MetadataRelationship | Yes | LOS_Stage__mdt |
| LOS_Application_Type__c | MetadataRelationship | No | LOS_Application_Type__mdt |
| LOS_Transition_Type__c | Text | Yes |  |
| LOS_Action_Label__c | Text | Yes |  |
| LOS_Requires_Reason__c | Checkbox | No |  |
| LOS_Requires_Validation__c | Checkbox | No |  |
| LOS_Validation_Policy_Code__c | Text | No |  |
| LOS_Sequence__c | Number | No |  |

Validation rules: None.

## LOS_Persona__mdt

Business persona catalog; grants no Salesforce permissions or record access by itself.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Display_Label__c | Text | Yes |  |

Validation rules: None.

## LOS_Workspace_Section__mdt

Future workspace layout configuration; component keys must be resolved by an allowlisted registry.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Application_Type__c | MetadataRelationship | No | LOS_Application_Type__mdt |
| LOS_Stage__c | MetadataRelationship | No | LOS_Stage__mdt |
| LOS_Persona__c | MetadataRelationship | No | LOS_Persona__mdt |
| LOS_Display_Label__c | Text | No |  |
| LOS_Component_Key__c | Text | No |  |
| LOS_Visibility_Policy_Code__c | Text | No |  |
| LOS_Sequence__c | Number | No |  |

Validation rules: None.

## LOS_Workspace_Action__mdt

Future workspace actions. Visibility does not authorize execution.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Application_Type__c | MetadataRelationship | No | LOS_Application_Type__mdt |
| LOS_Stage__c | MetadataRelationship | No | LOS_Stage__mdt |
| LOS_Persona__c | MetadataRelationship | No | LOS_Persona__mdt |
| LOS_Section__c | MetadataRelationship | No | LOS_Workspace_Section__mdt |
| LOS_Transition__c | MetadataRelationship | No | LOS_Stage_Transition__mdt |
| LOS_Display_Label__c | Text | No |  |
| LOS_Handler_Key__c | Text | No |  |
| LOS_Authorization_Policy_Code__c | Text | No |  |
| LOS_Sequence__c | Number | No |  |
| LOS_Requires_Confirmation__c | Checkbox | No |  |

Validation rules: None.

## LOS_SLA_Rule__mdt

Configurable SLA targets; business hours are resolved by a portable key, not an org ID.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Application_Type__c | MetadataRelationship | No | LOS_Application_Type__mdt |
| LOS_Stage__c | MetadataRelationship | No | LOS_Stage__mdt |
| LOS_Persona__c | MetadataRelationship | No | LOS_Persona__mdt |
| LOS_Org_Unit_Type__c | MetadataRelationship | No | LOS_Org_Unit_Type__mdt |
| LOS_Target_Minutes__c | Number | No |  |
| LOS_Warning_Minutes__c | Number | No |  |
| LOS_Priority__c | Number | No |  |
| LOS_Business_Hours_Key__c | Text | No |  |
| LOS_Effective_From__c | Date | No |  |
| LOS_Effective_To__c | Date | No |  |

Validation rules: None.

## LOS_TAT_Pause_Rule__mdt

Configured pause reasons and captured SLA-counting policy. Gross pause durations are measured by the runtime.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Application_Type__c | MetadataRelationship | No | LOS_Application_Type__mdt |
| LOS_Stage__c | MetadataRelationship | No | LOS_Stage__mdt |
| LOS_Display_Label__c | Text | No |  |
| LOS_Count_Toward_SLA__c | Checkbox | No |  |
| LOS_Requires_Comments__c | Checkbox | No |  |
| LOS_Sequence__c | Number | No |  |

Validation rules: None.

## LOS_Org_Unit_Type__mdt

Client-defined unit taxonomy. No fixed hierarchy depth or level semantics.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Description__c | LongTextArea | No |  |
| LOS_Display_Label__c | Text | Yes |  |
| LOS_Sequence__c | Number | No |  |

Validation rules: None.

## LOS_Organization_Unit__c

Generic organization hierarchy. Unit type resolves to active Org Unit Type metadata by Code.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Code__c | Text | Yes |  |
| LOS_Unit_Type__c | Text | Yes |  |
| LOS_Parent_Unit__c | Lookup | No | LOS_Organization_Unit__c |
| LOS_Effective_From__c | Date | No |  |
| LOS_Effective_To__c | Date | No |  |
| LOS_Active__c | Checkbox | No |  |

Validation rules: LOS_Effective_Dates, LOS_No_Self_Parent.

## LOS_User_Org_Assignment__c

Many-to-many effective-dated user membership; interpreted by a future visibility engine.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_User__c | Lookup | Validation rule | User |
| LOS_Organization_Unit__c | Lookup | Yes | LOS_Organization_Unit__c |
| LOS_Persona_Code__c | Text | Yes |  |
| LOS_Access_Level__c | Text | Yes |  |
| LOS_Effective_From__c | Date | No |  |
| LOS_Effective_To__c | Date | No |  |
| LOS_Active__c | Checkbox | No |  |

Validation rules: LOS_Effective_Dates, LOS_Required_User.

## LOS_Relationship__c

Customer relationship; current organization context may change independently of application snapshots.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Relationship_Number__c | Text | Yes |  |
| LOS_Account__c | Lookup | Yes | Account |
| LOS_Primary_RM__c | Lookup | No | User |
| LOS_Primary_Organization_Unit__c | Lookup | Yes | LOS_Organization_Unit__c |
| LOS_Business_Unit_Snapshot__c | Text | No |  |
| LOS_Segment_Snapshot__c | Text | No |  |
| LOS_Branch_Snapshot__c | Text | No |  |
| LOS_Status__c | Text | No |  |
| LOS_Active__c | Checkbox | No |  |

Validation rules: None.

## LOS_Credit_Application__c

Service-managed application with organization snapshots captured at creation, configured lifecycle state and optimistic runtime version.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Relationship__c | Lookup | Yes | LOS_Relationship__c |
| LOS_Application_Type__c | Text | Yes |  |
| LOS_Current_Stage__c | Text | Yes |  |
| LOS_Status__c | Text | No |  |
| LOS_Primary_RM__c | Lookup | No | User |
| LOS_Current_Owner_User__c | Lookup | No | User |
| LOS_Current_Queue_Key__c | Text | No |  |
| LOS_Organization_Unit__c | Lookup | Yes | LOS_Organization_Unit__c |
| LOS_Business_Unit_Snapshot__c | Text | No |  |
| LOS_Segment_Snapshot__c | Text | No |  |
| LOS_Branch_Snapshot__c | Text | No |  |
| LOS_Rework_Count__c | Number | No |  |
| LOS_Current_Rework_Number__c | Number | No |  |
| LOS_Submitted_Date__c | DateTime | No |  |
| LOS_Approved_Date__c | DateTime | No |  |
| LOS_Booking_Date__c | DateTime | No |  |
| LOS_Active__c | Checkbox | No |  |
| LOS_Baseline_Application__c | Lookup | No | LOS_Credit_Application__c |
| LOS_Previous_Approved_Application__c | Lookup | No | LOS_Credit_Application__c |
| LOS_Runtime_Version__c | Number | No |  |

Validation rules: LOS_No_Self_Reference, LOS_Nonnegative_Measures.

## LOS_Application_Team__c

Effective-dated application participation; supplements future organizational sharing.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Credit_Application__c | Lookup | Yes | LOS_Credit_Application__c |
| LOS_User__c | Lookup | Validation rule | User |
| LOS_Persona_Code__c | Text | Yes |  |
| LOS_Access_Level__c | Text | Yes |  |
| LOS_Effective_From__c | Date | No |  |
| LOS_Effective_To__c | Date | No |  |
| LOS_Active__c | Checkbox | No |  |

Validation rules: LOS_Effective_Dates, LOS_Required_User.

## LOS_Lifecycle_History__c

Immutable lifecycle events. Runtime-only insertion; triggers reject update, delete and undelete. The Task 01 immutable validation rule remains active.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Credit_Application__c | Lookup | Yes | LOS_Credit_Application__c |
| LOS_From_Stage__c | Text | No |  |
| LOS_To_Stage__c | Text | Yes |  |
| LOS_Transition_Type__c | Text | Yes |  |
| LOS_Transition_Date_Time__c | DateTime | Yes |  |
| LOS_Performed_By__c | Lookup | Validation rule | User |
| LOS_Reason__c | LongTextArea | No |  |
| LOS_Comments__c | LongTextArea | No |  |
| LOS_Rework_Number__c | Number | No |  |

Validation rules: LOS_Immutable_History, LOS_Nonnegative_Measures, LOS_Required_Performed_By.

## LOS_Stage_TAT__c

Service-managed stage interval with unique open context, captured SLA target/calendar key and gross duration measurements.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Application__c | Lookup | Yes | LOS_Credit_Application__c |
| LOS_Stage__c | Text | Yes |  |
| LOS_Rework_Number__c | Number | No |  |
| LOS_Start_Date_Time__c | DateTime | Yes |  |
| LOS_End_Date_Time__c | DateTime | No |  |
| LOS_Gross_Minutes__c | Number | No |  |
| LOS_Business_Minutes__c | Number | No |  |
| LOS_Paused_Minutes__c | Number | No |  |
| LOS_SLA_Target_Minutes__c | Number | No |  |
| LOS_SLA_Status__c | Text | No |  |
| LOS_Started_By__c | Lookup | Validation rule | User |
| LOS_Completed_By__c | Lookup | No | User |
| LOS_Calendar_Key__c | Text | No |  |
| LOS_Open_Context_Key__c | Text | No |  |

Validation rules: LOS_Date_Order, LOS_Nonnegative_Measures, LOS_Required_Started_By.

## LOS_Assignment_TAT__c

Assignment interval to exactly one user or queue key within a stage TAT.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Stage_TAT__c | Lookup | Yes | LOS_Stage_TAT__c |
| LOS_Application__c | Lookup | Yes | LOS_Credit_Application__c |
| LOS_User__c | Lookup | No | User |
| LOS_Queue_Key__c | Text | No |  |
| LOS_Assignment_Start__c | DateTime | Yes |  |
| LOS_Assignment_End__c | DateTime | No |  |
| LOS_Business_Minutes__c | Number | No |  |
| LOS_Assignment_Type__c | Text | Yes |  |

Validation rules: LOS_Date_Order, LOS_Exactly_One_Assignee, LOS_Matching_Application, LOS_Nonnegative_Measures.

## LOS_TAT_Pause__c

Pause interval and captured SLA counting policy; parent application must match the stage interval.

| Field | Type | Required | Reference |
|---|---|---|---|
| LOS_Stage_TAT__c | Lookup | Yes | LOS_Stage_TAT__c |
| LOS_Application__c | Lookup | Yes | LOS_Credit_Application__c |
| LOS_Pause_Reason__c | Text | Yes |  |
| LOS_Pause_Start__c | DateTime | Yes |  |
| LOS_Pause_End__c | DateTime | No |  |
| LOS_Count_Toward_SLA__c | Checkbox | No |  |
| LOS_Comments__c | LongTextArea | No |  |
| LOS_Open_Context_Key__c | Text | No |  |

Validation rules: LOS_Date_Order, LOS_Matching_Application.
