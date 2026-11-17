// 002 Partner referral demo, step 5 of 5: schedule the hourly SLA monitor and the daily payout check
// (the payout job only acts on the first business day of the month). Safe to re-run.
Set<String> names = new Set<String>();
for (CronTrigger ct : [SELECT CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'PR %']) names.add(ct.CronJobDetail.Name);
if (!names.contains('PR SLA monitor')) System.schedule('PR SLA monitor', '0 5 * * * ?', new PR_SlaMonitorJob());
if (!names.contains('PR monthly payout')) System.schedule('PR monthly payout', '0 0 6 * * ?', new PR_PayoutBatchJob());
System.debug('PR-DEMO step 5 done');
