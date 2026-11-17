// 002 Partner referral demo, step 6 (after the Connectnow Partners site is deployed with the
// "Connectnow Partner User" profile as a member): sets one demo password for every demo partner user.
//
// Before running, replace CHANGE_ME below with the password you want, locally. Never commit the real value,
// and never log it: this script deliberately prints only how many users were updated. Re-run with a new value
// to rotate the demo passwords.
String password = 'CHANGE_ME';
if (password == 'CHANGE_ME' || password.length() < 12) {
    throw new IllegalArgumentException('Set a demo password of at least 12 characters in this script first (locally only).');
}
Integer n = 0;
for (User u : [SELECT Id FROM User WHERE Username LIKE '%@connectnow-partners.demo' AND IsActive = TRUE]) {
    System.setPassword(u.Id, password);
    n++;
}
System.debug('PR-DEMO step 6 done: password set for ' + n + ' demo partner users');
