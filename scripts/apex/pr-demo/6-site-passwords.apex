// 002 Partner referral demo, step 6 (after the Connectnow Partners site is deployed with the
// "Connectnow Partner User" profile as a member): sets one demo password for every demo partner user and
// prints it to the debug log. Never commit the printed password.
String password = 'Connectnow!' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 9000) + 1000);
for (User u : [SELECT Id FROM User WHERE Username LIKE '%@connectnow-partners.demo' AND IsActive = TRUE]) {
    System.setPassword(u.Id, password);
}
System.debug('PR-DEMO-PASSWORD ' + password);
