# Salesforce Transaction Index & Order of Execution

## SObject: Contact
### Event: UPDATE
- **Step 9** [APEX_TRIGGER] `WorkdayContactTrigger`
- **Step 21** [ASYNC_JOB] `WorkdayContactTrigger (Async)`

## SObject: Shift_Forecast__c
### Event: INSERT
- **Step 14** [FLOW] `Create_Open_Shift_From_Forecast`

### Event: UPDATE
- **Step 14** [FLOW] `Create_Open_Shift_From_Forecast`

## SObject: WorkdaySyncScheduler
### Event: INSERT
- **Step 21** [ASYNC_JOB] `WorkdaySyncScheduler (Async)`

### Event: UPDATE
- **Step 21** [ASYNC_JOB] `WorkdaySyncScheduler (Async)`

### Event: DELETE
- **Step 21** [ASYNC_JOB] `WorkdaySyncScheduler (Async)`

## SObject: WorkdayWorkerSyncJob
### Event: INSERT
- **Step 21** [ASYNC_JOB] `WorkdayWorkerSyncJob (Async)`

### Event: UPDATE
- **Step 21** [ASYNC_JOB] `WorkdayWorkerSyncJob (Async)`

### Event: DELETE
- **Step 21** [ASYNC_JOB] `WorkdayWorkerSyncJob (Async)`
