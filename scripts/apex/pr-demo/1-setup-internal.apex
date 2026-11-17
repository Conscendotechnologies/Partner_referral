// 002 Partner referral demo, step 1 of 5 (setup objects only).
// Gives the running admin a role (needed to own partner agencies), the internal PR permission sets,
// and membership of every PR sales queue. Safe to re-run.
User me = [SELECT Id, UserRoleId FROM User WHERE Id = :UserInfo.getUserId()];
if (me.UserRoleId == null) {
    List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = 'Connectnow_Partner_Program' LIMIT 1];
    UserRole r = roles.isEmpty() ? new UserRole(Name = 'Connectnow Partner Program', DeveloperName = 'Connectnow_Partner_Program') : roles[0];
    if (r.Id == null) insert r;
    me.UserRoleId = r.Id;
    update me;
}

Set<Id> have = new Set<Id>();
for (PermissionSetAssignment a : [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :me.Id]) have.add(a.PermissionSetId);
List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
for (PermissionSet p : [SELECT Id FROM PermissionSet WHERE Name IN ('PR_Partner_Manager', 'PR_Sales_Rep', 'PR_Finance')]) {
    if (!have.contains(p.Id)) psas.add(new PermissionSetAssignment(AssigneeId = me.Id, PermissionSetId = p.Id));
}
insert psas;

Set<Id> inQueue = new Set<Id>();
for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :me.Id]) inQueue.add(gm.GroupId);
List<GroupMember> members = new List<GroupMember>();
for (Group q : [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName LIKE 'PR%']) {
    if (!inQueue.contains(q.Id)) members.add(new GroupMember(GroupId = q.Id, UserOrGroupId = me.Id));
}
insert members;
System.debug('PR-DEMO step 1 done: role set, ' + psas.size() + ' permission sets, ' + members.size() + ' queues');
