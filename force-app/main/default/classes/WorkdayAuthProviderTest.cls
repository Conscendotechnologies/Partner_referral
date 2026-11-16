@IsTest
private class WorkdayAuthProviderTest {

    private class TokenMock implements HttpCalloutMock {
        Integer status = 200;
        String lastBody;

        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getHeader('Authorization').startsWith('ID '), req.getHeader('Authorization'));
            System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('client-1:secret-1')),
                req.getHeader('Authorization').substring(3));
            lastBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(status == 200
                ? '{"access_token":"at-1","refresh_token":"rt-1","token_type":"Bearer"}'
                : '{"error":"invalid_grant"}');
            return res;
        }
    }

    private static Map<String, String> config() {
        return new Map<String, String>{
            'Client_Id__c' => 'client-1',
            'Client_Secret__c' => 'secret-1',
            'Authorize_URL__c' => 'https://auth.example.com/v1/authorize',
            'Token_URL__c' => 'https://auth.example.com/v1/token',
            'Redirect_URL__c' => 'https://org.my.salesforce.com/services/authcallback/Workday'
        };
    }

    @IsTest
    static void initiateBuildsAuthorizeUrl() {
        WorkdayAuthProvider provider = new WorkdayAuthProvider();
        System.assertEquals('Workday_Auth_Provider__mdt', provider.getCustomMetadataType());
        String url = provider.initiate(config(), 'st 1').getUrl();
        System.assert(url.startsWith('https://auth.example.com/v1/authorize?'), url);
        System.assert(url.contains('response_type=code'), url);
        System.assert(url.contains('client_id=client-1'), url);
        System.assert(url.contains('state=st+1'), url);
    }

    @IsTest
    static void callbackExchangesCodeAndRefreshWorks() {
        TokenMock mock = new TokenMock();
        Test.setMock(HttpCalloutMock.class, mock);
        WorkdayAuthProvider provider = new WorkdayAuthProvider();

        Auth.AuthProviderTokenResponse tokens = provider.handleCallback(config(),
            new Auth.AuthProviderCallbackState(null, null,
                new Map<String, String>{ 'code' => 'abc', 'state' => 'st' }));
        System.assertEquals('at-1', tokens.oauthToken);
        System.assertEquals('rt-1', tokens.oauthSecretOrRefreshToken);
        System.assertEquals('st', tokens.state);
        System.assert(mock.lastBody.contains('grant_type=authorization_code'), mock.lastBody);

        Auth.OAuthRefreshResult refreshed = provider.refresh(config(), 'rt-0');
        System.assertEquals('at-1', refreshed.accessToken);
        System.assertEquals('rt-1', refreshed.refreshToken);
        System.assertEquals(null, refreshed.error);
        System.assert(mock.lastBody.contains('grant_type=refresh_token'), mock.lastBody);

        System.assertEquals('workday-integration', provider.getUserInfo(config(), tokens).identifier);
    }

    @IsTest
    static void failuresAreReported() {
        TokenMock mock = new TokenMock();
        mock.status = 400;
        Test.setMock(HttpCalloutMock.class, mock);
        WorkdayAuthProvider provider = new WorkdayAuthProvider();

        try {
            provider.handleCallback(config(), new Auth.AuthProviderCallbackState(null, null,
                new Map<String, String>{ 'error' => 'access_denied' }));
            System.assert(false, 'Expected missing code to fail');
        } catch (WorkdayAuthProvider.WorkdayAuthException e) {
            System.assert(e.getMessage().contains('access_denied'), e.getMessage());
        }
        try {
            provider.refresh(config(), 'rt-0');
            System.assert(false, 'Expected token failure');
        } catch (WorkdayAuthProvider.WorkdayAuthException e) {
            System.assert(e.getMessage().contains('400'), e.getMessage());
        }
    }
}
