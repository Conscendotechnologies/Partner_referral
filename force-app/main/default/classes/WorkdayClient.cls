/**
 * Thin client for the Workday REST API. Authentication is handled entirely by
 * the Workday_API named credential: its Workday external credential runs the
 * OAuth browser flow through the Workday auth provider, stores the refresh
 * token and adds the bearer header, so Apex never sees a token or secret.
 */
public with sharing class WorkdayClient {

    public class WorkdayException extends Exception {}

    public class WorkersPage {
        public Integer total;
        public List<Map<String, Object>> workers = new List<Map<String, Object>>();
    }

    private final Workday_Setting__mdt settings;

    public WorkdayClient() {
        this(Workday_Setting__mdt.getInstance('Default'));
    }

    public WorkdayClient(Workday_Setting__mdt settings) {
        if (settings == null) {
            throw new WorkdayException('Workday_Setting__mdt "Default" record is missing.');
        }
        this.settings = settings;
    }

    public Workday_Setting__mdt getSettings() {
        return settings;
    }

    /** One page of the workers collection. */
    public WorkersPage getWorkers(Integer offset, Integer pageSize) {
        String path = settings.Workers_Path__c.replace('{tenant}', settings.Tenant__c);
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('callout:Workday_API' + path + '?limit=' + pageSize + '&offset=' + offset);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);

        Map<String, Object> body = send(req);
        WorkersPage page = new WorkersPage();
        page.total = body.get('total') == null ? 0 : Integer.valueOf(body.get('total'));
        List<Object> data = (List<Object>) body.get('data');
        if (data != null) {
            for (Object row : data) {
                page.workers.add((Map<String, Object>) row);
            }
        }
        return page;
    }

    /**
     * Starts a Change Business Title event in Workday. Workday applies it at once
     * when the connected user may approve it (e.g. their own direct reports);
     * otherwise it waits in the approver's inbox. Returns true when applied.
     */
    public Boolean changeBusinessTitle(String workdayId, String title) {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:Workday_API/common/v1/workers/' + workdayId + '/businessTitleChanges');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{ 'proposedBusinessTitle' => title }));
        req.setTimeout(60000);
        send(req);

        HttpRequest check = new HttpRequest();
        check.setMethod('GET');
        check.setEndpoint('callout:Workday_API/common/v1/workers/' + workdayId);
        check.setTimeout(60000);
        return title == (String) send(check).get('businessTitle');
    }

    private static Map<String, Object> send(HttpRequest req) {
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() > 299) {
            throw new WorkdayException('Workday ' + req.getMethod() + ' ' + req.getEndpoint()
                + ' failed: ' + res.getStatusCode() + ' ' + res.getBody().left(500));
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }
}
