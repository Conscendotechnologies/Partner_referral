@IsTest
private class DocumentGeneratorTest {

    private static Account makeAccount() {
        Account a = new Account(
            Name = 'Testing Freight Sdn Bhd',
            BillingStreet = '12 Jalan Ampang',
            BillingCity = 'Kuala Lumpur',
            BillingState = 'WP',
            BillingPostalCode = '50450',
            BillingCountry = 'Malaysia'
        );
        insert a;
        return a;
    }

    private static Order makeOrder(Account a) {
        Order o = new Order(
            AccountId = a.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            PoNumber = 'PO-TEST-001',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert o;
        return o;
    }

    @IsTest
    static void buildsPurchaseOrderDocument() {
        Account a = makeAccount();
        Order o = makeOrder(a);

        Test.startTest();
        DocumentTemplateService.DocumentModel m = DocumentTemplateService.build(o.Id);
        Test.stopTest();

        System.assertEquals('Order', m.objectApiName, 'Object should resolve from the id');
        System.assertEquals('PURCHASE ORDER', m.documentTitle, 'Title comes from metadata');
        System.assertEquals(a.Name, m.accountName, 'Account should resolve via Account_Path__c');
        System.assert(m.accountAddress.contains('Kuala Lumpur'), 'Address should be assembled');
        System.assert(!m.details.isEmpty(), 'Detail rows should be populated');
        System.assert(m.showLineItems, 'Purchase Order template shows line items');
        System.assert(m.hasTotals, 'Totals should be calculated');
    }

    @IsTest
    static void buildsInvoiceDocumentWithBalance() {
        Account a = makeAccount();
        Order o = makeOrder(a);
        Invoice__c inv = new Invoice__c(
            Account__c = a.Id,
            Purchase_Order__c = o.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Send to Maxis',
            Subtotal__c = 9155,
            Tax__c = 549.30,
            Total_Amount__c = 9704.30,
            Amount_Paid__c = 4000
        );
        insert inv;

        Test.startTest();
        DocumentTemplateService.DocumentModel m = DocumentTemplateService.build(inv.Id);
        Test.stopTest();

        System.assertEquals('TAX INVOICE', m.documentTitle, 'Invoice title from metadata');
        System.assertEquals(a.Name, m.accountName, 'Invoice resolves account directly');

        Invoice__c reloaded = [SELECT Balance_Due__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(5704.30, reloaded.Balance_Due__c, 'Balance Due formula should net off payment');
    }

    @IsTest
    static void buildsReceiptThroughInvoiceToAccount() {
        Account a = makeAccount();
        Invoice__c inv = new Invoice__c(Account__c = a.Id, Total_Amount__c = 500);
        insert inv;
        Payment_Receipt__c r = new Payment_Receipt__c(
            Invoice__c = inv.Id,
            Amount__c = 500,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Bank Transfer',
            Payment_Reference__c = 'TRX-0099',
            Status__c = 'Payment Received'
        );
        insert r;

        Test.startTest();
        DocumentTemplateService.DocumentModel m = DocumentTemplateService.build(r.Id);
        Test.stopTest();

        System.assertEquals('PAYMENT RECEIPT', m.documentTitle, 'Receipt title from metadata');
        System.assertEquals(a.Name, m.accountName,
            'Account should resolve two hops through Invoice__r.Account__r');
        System.assert(!m.showLineItems, 'Receipts do not show line items');
    }

    @IsTest
    static void buildsCreditNote() {
        Account a = makeAccount();
        Invoice__c inv = new Invoice__c(Account__c = a.Id, Total_Amount__c = 800);
        insert inv;
        Credit_Debit_Note__c n = new Credit_Debit_Note__c(
            Invoice__c = inv.Id,
            Type__c = 'Credit Note',
            Amount__c = 250,
            Note_Date__c = Date.today(),
            Reason__c = 'Goods Returned'
        );
        insert n;

        Test.startTest();
        DocumentTemplateService.DocumentModel m = DocumentTemplateService.build(n.Id);
        Test.stopTest();

        System.assertEquals('CREDIT / DEBIT NOTE', m.documentTitle, 'Note title from metadata');
        System.assert(!m.details.isEmpty(), 'Note detail rows should be populated');
    }

    @IsTest
    static void savesPdfAgainstTheRecord() {
        Account a = makeAccount();
        Order o = makeOrder(a);

        Test.startTest();
        DocumentGeneratorController.FileInfo info =
            DocumentGeneratorController.savePdfToRecord(o.Id);
        List<DocumentGeneratorController.FileInfo> files =
            DocumentGeneratorController.getSavedFiles(o.Id);
        Test.stopTest();

        System.assertNotEquals(null, info.contentDocumentId, 'A file should have been created');
        System.assertEquals(1, files.size(), 'The saved file should be linked to the record');
        System.assert(files[0].downloadUrl.contains('download'), 'Download url should be built');
    }

    @IsTest
    static void controllerSurfacesDocumentAndUrl() {
        Account a = makeAccount();
        Order o = makeOrder(a);

        Test.startTest();
        DocumentTemplateService.DocumentModel m =
            DocumentGeneratorController.getDocument(o.Id);
        String url = DocumentGeneratorController.getPdfUrl(o.Id);
        List<DocumentGeneratorController.FileInfo> none =
            DocumentGeneratorController.getSavedFiles(o.Id);
        Test.stopTest();

        System.assertEquals('PURCHASE ORDER', m.documentTitle, 'Controller delegates to the service');
        System.assert(url.contains('/apex/DocumentPdf?id='), 'PDF url should point at the VF page');
        System.assert(none.isEmpty(), 'No files saved yet for this record');
    }

    @IsTest
    static void visualforceControllerRendersAndReportsErrors() {
        Account a = makeAccount();
        Order o = makeOrder(a);

        Test.startTest();
        // happy path
        PageReference good = Page.DocumentPdf;
        good.getParameters().put('id', o.Id);
        Test.setCurrentPage(good);
        DocumentPdfController ok = new DocumentPdfController();

        // missing id
        Test.setCurrentPage(Page.DocumentPdf);
        DocumentPdfController missing = new DocumentPdfController();

        // object with no template configured
        PageReference bad = Page.DocumentPdf;
        bad.getParameters().put('id', a.Id);
        Test.setCurrentPage(bad);
        DocumentPdfController unmapped = new DocumentPdfController();
        Test.stopTest();

        System.assertEquals(false, ok.getHasError(), 'A mapped record should render');
        System.assertEquals('PURCHASE ORDER', ok.doc.documentTitle, 'Model should be built');
        System.assert(missing.getHasError(), 'A missing id should be reported');
        System.assert(unmapped.getHasError(), 'Account has no template, should be reported');
    }

    @IsTest
    static void relationshipPathHandlesEveryLookupShape() {
        System.assertEquals('Account',
            DocumentTemplateService.relationshipPath('AccountId'), 'Standard lookup');
        System.assertEquals('Account__r',
            DocumentTemplateService.relationshipPath('Account__c'), 'Custom lookup');
        System.assertEquals('Invoice__r.Account__r',
            DocumentTemplateService.relationshipPath('Invoice__r.Account__c'), 'Two hops');
        System.assertEquals(null,
            DocumentTemplateService.relationshipPath(null), 'Null is tolerated');
    }
}
