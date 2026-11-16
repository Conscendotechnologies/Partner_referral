/**
 * Custom auth provider for the Workday Developer Platform OAuth endpoints.
 * Workday's token endpoint expects "Authorization: ID base64(clientId:secret)"
 * rather than Basic, which the standard OpenID Connect provider cannot send.
 * The Workday external credential uses this provider for its browser flow;
 * Salesforce then stores the refresh token and calls refresh() as needed.
 */
public with sharing class WorkdayAuthProvider extends Auth.AuthProviderPluginClass {

    public class WorkdayAuthException extends Exception {}

    public String getCustomMetadataType() {
        return 'Workday_Auth_Provider__mdt';
    }

    public PageReference initiate(Map<String, String> config, String stateToPropagate) {
        return new PageReference(config.get('Authorize_URL__c')
            + '?response_type=code'
            + '&client_id=' + EncodingUtil.urlEncode(config.get('Client_Id__c'), 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(config.get('Redirect_URL__c'), 'UTF-8')
            + '&state=' + EncodingUtil.urlEncode(stateToPropagate, 'UTF-8'));
    }

    public Auth.AuthProviderTokenResponse handleCallback(Map<String, String> config, Auth.AuthProviderCallbackState state) {
        String code = state.queryParameters.get('code');
        if (String.isBlank(code)) {
            throw new WorkdayAuthException('Workday did not return an authorization code: '
                + state.queryParameters.get('error') + ' ' + state.queryParameters.get('error_description'));
        }
        Map<String, Object> token = requestToken(config,
            'grant_type=authorization_code'
            + '&code=' + EncodingUtil.urlEncode(code, 'UTF-8')
            + '&client_id=' + EncodingUtil.urlEncode(config.get('Client_Id__c'), 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(config.get('Redirect_URL__c'), 'UTF-8'));
        return new Auth.AuthProviderTokenResponse('Workday',
            (String) token.get('access_token'),
            (String) token.get('refresh_token'),
            state.queryParameters.get('state'));
    }

    public override Auth.OAuthRefreshResult refresh(Map<String, String> config, String refreshToken) {
        Map<String, Object> token = requestToken(config,
            'grant_type=refresh_token&refresh_token=' + EncodingUtil.urlEncode(refreshToken, 'UTF-8'));
        String newRefresh = (String) token.get('refresh_token');
        // Signature is (accessToken, refreshToken, error); a non-null error marks the refresh failed.
        return new Auth.OAuthRefreshResult((String) token.get('access_token'),
            String.isBlank(newRefresh) ? refreshToken : newRefresh, null);
    }

    /** Workday exposes no userinfo endpoint here; named principals do not need one. */
    public Auth.UserData getUserInfo(Map<String, String> config, Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData('workday-integration', null, null, null, null, null,
            'workday-integration', null, 'Workday', null, new Map<String, String>());
    }

    private static Map<String, Object> requestToken(Map<String, String> config, String body) {
        String credentials = config.get('Client_Id__c') + ':' + config.get('Client_Secret__c');
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(config.get('Token_URL__c'));
        req.setHeader('Authorization', 'ID ' + EncodingUtil.base64Encode(Blob.valueOf(credentials)));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        // Status and response field names only - never log token values.
        System.debug('Workday token response ' + res.getStatusCode() + ' fields='
            + (res.getStatusCode() == 200
                ? String.valueOf(((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).keySet())
                : res.getBody().left(300)));
        if (res.getStatusCode() != 200) {
            throw new WorkdayAuthException('Workday token request failed: '
                + res.getStatusCode() + ' ' + res.getBody().left(500));
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }
}
