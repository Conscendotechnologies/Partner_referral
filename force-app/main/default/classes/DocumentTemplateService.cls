/**
 * Resolves any record into a printable document model, driven entirely by
 * Document_Template__mdt configuration. Adding a new document type to the demo
 * means adding a custom metadata record, not editing this class.
 */
public with sharing class DocumentTemplateService {

    public class DocumentException extends Exception {}

    private static final String COMPANY_NAME = 'Global Feeder Shipping LLC';
    private static final Decimal TAX_RATE = 0.05;

    // ---------------------------------------------------------------- models

    public class DocRow {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public DocRow(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class LineItem {
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String quantity { get; set; }
        @AuraEnabled public String unitPrice { get; set; }
        @AuraEnabled public String lineTotal { get; set; }
        public LineItem(String description, Decimal qty, Decimal unit, Decimal total) {
            this.description = description;
            this.quantity  = qty == null ? '' : String.valueOf(qty.setScale(0));
            this.unitPrice = money(unit);
            this.lineTotal = money(total);
        }
    }

    public class DocumentModel {
        @AuraEnabled public String  objectApiName  { get; set; }
        @AuraEnabled public String  documentTitle  { get; set; }
        @AuraEnabled public String  accentColor    { get; set; }
        @AuraEnabled public String  recordName     { get; set; }
        @AuraEnabled public String  companyName    { get; set; }
        @AuraEnabled public String  accountName    { get; set; }
        @AuraEnabled public String  accountAddress { get; set; }
        @AuraEnabled public String  generatedOn    { get; set; }
        @AuraEnabled public Boolean showLineItems  { get; set; }
        @AuraEnabled public List<DocRow>   details   { get; set; }
        @AuraEnabled public List<LineItem> lineItems { get; set; }
        @AuraEnabled public String  subtotal   { get; set; }
        @AuraEnabled public String  taxAmount  { get; set; }
        @AuraEnabled public String  grandTotal { get; set; }
        @AuraEnabled public Boolean hasTotals  { get; set; }
    }

    // ------------------------------------------------------------------ main

    public static DocumentModel build(Id recordId) {
        if (recordId == null) {
            throw new DocumentException('No record id supplied.');
        }
        String objName = recordId.getSObjectType().getDescribe().getName();

        List<Document_Template__mdt> templates = [
            SELECT Document_Title__c, Accent_Color__c, Detail_Fields__c,
                   Show_Line_Items__c, Account_Path__c, Object_API_Name__c
            FROM Document_Template__mdt
            WHERE Object_API_Name__c = :objName AND Active__c = true
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw new DocumentException(
                'No active Document Template is configured for ' + objName + '.');
        }
        Document_Template__mdt cfg = templates[0];

        DocumentModel model = new DocumentModel();
        model.objectApiName = objName;
        model.documentTitle = cfg.Document_Title__c;
        model.accentColor   = String.isBlank(cfg.Accent_Color__c) ? '#1F3A5F' : cfg.Accent_Color__c;
        model.companyName   = COMPANY_NAME;
        model.generatedOn   = Datetime.now().format('d MMMM yyyy');
        model.showLineItems = cfg.Show_Line_Items__c == true;
        model.details       = new List<DocRow>();
        model.lineItems     = new List<LineItem>();

        SObject record = queryRecord(recordId, objName, cfg);
        model.recordName = String.valueOf(record.get(nameFieldOf(objName)));

        populateDetails(model, record, objName, cfg);
        populateAccount(model, record, cfg);

        if (model.showLineItems) {
            model.lineItems = lineItemsFor(recordId, objName, record);
        }
        applyTotals(model);
        return model;
    }

    // --------------------------------------------------------------- helpers

    private static SObject queryRecord(Id recordId, String objName, Document_Template__mdt cfg) {
        Set<String> fields = new Set<String>{ 'Id', nameFieldOf(objName) };
        for (String f : detailFieldsOf(cfg)) {
            fields.add(f);
        }
        String rel = relationshipPath(cfg.Account_Path__c);
        if (rel != null) {
            for (String af : new List<String>{
                    'Name', 'BillingStreet', 'BillingCity',
                    'BillingState', 'BillingPostalCode', 'BillingCountry' }) {
                fields.add(rel + '.' + af);
            }
        }
        if (objName == 'Invoice__c') {
            fields.add('Purchase_Order__c');
        }
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ')
                    + ' FROM ' + objName + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty()) {
            throw new DocumentException('Record not found or not visible to you.');
        }
        return rows[0];
    }

    private static List<String> detailFieldsOf(Document_Template__mdt cfg) {
        List<String> out = new List<String>();
        if (String.isBlank(cfg.Detail_Fields__c)) {
            return out;
        }
        for (String raw : cfg.Detail_Fields__c.split(',')) {
            String f = raw.trim();
            if (String.isNotBlank(f)) {
                out.add(f);
            }
        }
        return out;
    }

    private static void populateDetails(DocumentModel model, SObject record,
                                        String objName, Document_Template__mdt cfg) {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap();

        for (String f : detailFieldsOf(cfg)) {
            Schema.SObjectField token = fieldMap.get(f);
            if (token == null) {
                continue;
            }
            Schema.DescribeFieldResult dfr = token.getDescribe();
            Object raw = record.get(f);
            model.details.add(new DocRow(dfr.getLabel(), formatValue(raw, dfr)));
        }
    }

    private static void populateAccount(DocumentModel model, SObject record,
                                        Document_Template__mdt cfg) {
        String rel = relationshipPath(cfg.Account_Path__c);
        if (rel == null) {
            return;
        }
        SObject cursor = record;
        for (String hop : rel.split('\\.')) {
            if (cursor == null) {
                break;
            }
            cursor = cursor.getSObject(hop);
        }
        if (cursor == null) {
            return;
        }
        model.accountName = (String) cursor.get('Name');
        List<String> parts = new List<String>();
        for (String f : new List<String>{
                'BillingStreet', 'BillingCity', 'BillingState',
                'BillingPostalCode', 'BillingCountry' }) {
            Object v = cursor.get(f);
            if (v != null && String.isNotBlank(String.valueOf(v))) {
                parts.add(String.valueOf(v));
            }
        }
        model.accountAddress = String.join(parts, ', ');
    }

    /** AccountId to Account, Account__c to Account__r, A__r.B__c to A__r.B__r */
    @TestVisible
    private static String relationshipPath(String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return null;
        }
        List<String> hops = new List<String>();
        for (String seg : fieldPath.trim().split('\\.')) {
            if (seg.endsWith('__c')) {
                hops.add(seg.removeEnd('__c') + '__r');
            } else if (seg.endsWith('__r')) {
                hops.add(seg);
            } else if (seg.endsWith('Id') && seg.length() > 2) {
                hops.add(seg.removeEnd('Id'));
            } else {
                hops.add(seg);
            }
        }
        return String.join(hops, '.');
    }

    private static String nameFieldOf(String objName) {
        for (Schema.SObjectField f :
                Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().values()) {
            if (f.getDescribe().isNameField()) {
                return f.getDescribe().getName();
            }
        }
        return 'Id';
    }

    // ------------------------------------------------------------ line items

    private static List<LineItem> lineItemsFor(Id recordId, String objName, SObject record) {
        List<LineItem> out = new List<LineItem>();
        Id orderId = null;

        if (objName == 'Order') {
            orderId = recordId;
        } else if (objName == 'Invoice__c') {
            orderId = (Id) record.get('Purchase_Order__c');
        } else if (objName == 'Quote') {
            for (QuoteLineItem q : [
                    SELECT Quantity, UnitPrice, TotalPrice, Product2.Name
                    FROM QuoteLineItem WHERE QuoteId = :recordId ORDER BY LineNumber ]) {
                out.add(new LineItem(
                    q.Product2 == null ? 'Line item' : q.Product2.Name,
                    q.Quantity, q.UnitPrice, q.TotalPrice));
            }
            return out.isEmpty() ? sampleLines() : out;
        }

        if (orderId != null) {
            for (OrderItem oi : [
                    SELECT Quantity, UnitPrice, TotalPrice, Product2.Name
                    FROM OrderItem WHERE OrderId = :orderId ]) {
                out.add(new LineItem(
                    oi.Product2 == null ? 'Line item' : oi.Product2.Name,
                    oi.Quantity, oi.UnitPrice, oi.TotalPrice));
            }
        }
        return out.isEmpty() ? sampleLines() : out;
    }

    /** Demo fallback so a PDF never renders an empty table in a screenshot. */
    private static List<LineItem> sampleLines() {
        return new List<LineItem>{
            new LineItem('Ocean freight - 40ft high cube container', 4, 1850.00, 7400.00),
            new LineItem('Terminal handling charge (origin)',        4,  320.00, 1280.00),
            new LineItem('Documentation and customs clearance',      1,  475.00,  475.00)
        };
    }

    private static void applyTotals(DocumentModel model) {
        if (model.showLineItems != true || model.lineItems.isEmpty()) {
            model.hasTotals = false;
            return;
        }
        Decimal sub = 0;
        for (LineItem li : model.lineItems) {
            sub += Decimal.valueOf(li.lineTotal.replace(',', ''));
        }
        Decimal tax = (sub * TAX_RATE).setScale(2);
        model.subtotal   = money(sub);
        model.taxAmount  = money(tax);
        model.grandTotal = money(sub + tax);
        model.hasTotals  = true;
    }

    // ---------------------------------------------------------------- format

    private static String formatValue(Object raw, Schema.DescribeFieldResult dfr) {
        if (raw == null) {
            return '-';
        }
        Schema.DisplayType t = dfr.getType();
        if (t == Schema.DisplayType.Currency || t == Schema.DisplayType.Double
                || t == Schema.DisplayType.Percent) {
            return money((Decimal) raw);
        }
        if (t == Schema.DisplayType.Date) {
            return ((Date) raw).format();
        }
        if (t == Schema.DisplayType.DateTime) {
            return ((Datetime) raw).format('d MMM yyyy, h:mm a');
        }
        if (t == Schema.DisplayType.Boolean) {
            return ((Boolean) raw) ? 'Yes' : 'No';
        }
        return String.valueOf(raw);
    }

    private static String money(Decimal d) {
        if (d == null) {
            return '0.00';
        }
        return d.setScale(2).format();
    }
}
