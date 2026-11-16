/**
 * Controller for the DocumentPdf Visualforce page. The page is generic: it
 * renders whatever DocumentTemplateService resolves for the id in the URL,
 * so one page serves every document type in the demo.
 */
public with sharing class DocumentPdfController {

    public DocumentTemplateService.DocumentModel doc { get; private set; }
    public String errorMessage { get; private set; }

    public DocumentPdfController() {
        String rid = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(rid)) {
            errorMessage = 'Add ?id=<recordId> to the URL to render a document.';
            return;
        }
        try {
            doc = DocumentTemplateService.build((Id) rid);
        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
    }

    public Boolean getHasError() {
        return errorMessage != null;
    }
}
