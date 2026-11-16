/**
 * Schedules the Workday worker sync. Run once from anonymous Apex:
 *   WorkdaySyncScheduler.scheduleDaily();
 */
public with sharing class WorkdaySyncScheduler implements Schedulable {

    public static final String JOB_NAME = 'Workday Worker Sync';

    public void execute(SchedulableContext context) {
        WorkdayWorkerSyncJob.start();
    }

    /** Daily at 02:00 org time. */
    public static Id scheduleDaily() {
        return System.schedule(JOB_NAME, '0 0 2 * * ?', new WorkdaySyncScheduler());
    }
}
