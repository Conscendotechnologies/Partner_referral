/**
 * Apex surface for the documentGenerator LWC. Everything here is object
 * agnostic - the component passes its recordId and the template configuration
 * decides what the document looks like.
 */
public with sharing class DocumentGeneratorController {

    public class FileInfo {
        @AuraEnabled public String contentDocumentId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String createdDate { get; set; }
        @AuraEnabled public String downloadUrl { get; set; }
    }

    /** Template-driven preview model for the record the component sits on. */
    @AuraEnabled(cacheable=true)
    public static DocumentTemplateService.DocumentModel getDocument(Id recordId) {
        try {
            return DocumentTemplateService.build(recordId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Relative URL of the Visualforce PDF for this record. */
    @AuraEnabled(cacheable=true)
    public static String getPdfUrl(Id recordId) {
        return '/apex/DocumentPdf?id=' + recordId;
    }

    /**
     * Renders the PDF once and stores it as a file against the record, so the
     * document that was issued stays the document that is downloaded later.
     */
    @AuraEnabled
    public static FileInfo savePdfToRecord(Id recordId) {
        try {
            DocumentTemplateService.DocumentModel model =
                DocumentTemplateService.build(recordId);

            String fileName = model.documentTitle.replace(' ', '_')
                            + '_' + model.recordName;

            PageReference pdfPage = Page.DocumentPdf;
            pdfPage.getParameters().put('id', recordId);

            Blob body;
            if (Test.isRunningTest()) {
                body = Blob.valueOf('Test PDF content');
            } else {
                body = pdfPage.getContentAsPDF();
            }

            ContentVersion cv = new ContentVersion(
                Title                  = fileName,
                PathOnClient           = fileName + '.pdf',
                VersionData            = body,
                FirstPublishLocationId = recordId,
                IsMajorVersion         = true
            );
            insert cv;

            ContentVersion saved = [
                SELECT ContentDocumentId, Title, CreatedDate
                FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];
            return toFileInfo(saved.ContentDocumentId, saved.Title, saved.CreatedDate);
        } catch (Exception e) {
            throw new AuraHandledException('Could not save the PDF: ' + e.getMessage());
        }
    }

    /** PDFs already stored against this record, newest first. */
    @AuraEnabled(cacheable=true)
    public static List<FileInfo> getSavedFiles(Id recordId) {
        List<FileInfo> out = new List<FileInfo>();
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId ]) {
            docIds.add(link.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return out;
        }
        for (ContentVersion cv : [
                SELECT ContentDocumentId, Title, CreatedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds AND IsLatest = true
                ORDER BY CreatedDate DESC ]) {
            out.add(toFileInfo(cv.ContentDocumentId, cv.Title, cv.CreatedDate));
        }
        return out;
    }

    private static FileInfo toFileInfo(Id docId, String title, Datetime created) {
        FileInfo f = new FileInfo();
        f.contentDocumentId = docId;
        f.title = title;
        f.createdDate = created.format('d MMM yyyy, h:mm a');
        f.downloadUrl = '/sfc/servlet.shepherd/document/download/' + docId;
        return f;
    }
}
