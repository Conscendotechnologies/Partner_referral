// 002 Partner referral demo, step 5 of 6: schedule the hourly SLA monitor and the daily payout check
// (the payout job only acts on the first business day of the month). Safe to re-run.
//
// A same-named job only counts as installed while it can still fire: WAITING, ACQUIRED, EXECUTING or PAUSED
// with a NextFireTime. Anything else (COMPLETE, DELETED, ERROR, BLOCKED, or no next fire time) is aborted and
// scheduled again, so a dead schedule is never mistaken for a running one.
Map<String, Schedulable> jobs = new Map<String, Schedulable>{
    'PR SLA monitor' => new PR_SlaMonitorJob(),
    'PR monthly payout' => new PR_PayoutBatchJob()
};
Map<String, String> crons = new Map<String, String>{
    'PR SLA monitor' => '0 5 * * * ?',
    'PR monthly payout' => '0 0 6 * * ?'
};
Set<String> liveStates = new Set<String>{ 'WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED' };
Set<String> live = new Set<String>();
for (CronTrigger ct : [SELECT Id, State, NextFireTime, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name IN :jobs.keySet()]) {
    if (liveStates.contains(ct.State) && ct.NextFireTime != null) {
        live.add(ct.CronJobDetail.Name);
    } else {
        System.abortJob(ct.Id);
        System.debug('PR-DEMO step 5: removed ' + ct.CronJobDetail.Name + ' in state ' + ct.State);
    }
}
for (String name : jobs.keySet()) {
    if (live.contains(name)) {
        System.debug('PR-DEMO step 5: ' + name + ' already scheduled');
    } else {
        System.schedule(name, crons.get(name), jobs.get(name));
        System.debug('PR-DEMO step 5: scheduled ' + name);
    }
}
System.debug('PR-DEMO step 5 done');
