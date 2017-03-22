
var request = require('request');
var sso_service_url=(process.env.SSO_SERVICE_URL || "http://sso:8080"),
  realm = (process.env.SSO_REALM || "coolstore"),
  sso_reg_user = (process.env.SSO_SERVICE_USER_NAME || "admin"),
  sso_reg_password = (process.env.SSO_SERVICE_USER_PASSWD || "coolstore"),
  coolstore_client_id = (process.env.COOLSTORE_CLIENT_ID || "web-ui"),
  coolstore_web_uri = (process.env.COOLSTORE_WEB_URI || "");;


var token_uri = sso_service_url + '/auth/realms/master/protocol/openid-connect/token'
console.log("fetching access token from " + token_uri);
request.post(
  {
    uri: token_uri,
    strictSSL: false,
    json: true,
    form: {
        username: sso_reg_user,
        password: sso_reg_password,
        grant_type: 'password',
        client_id: 'admin-cli'
    }
  },
  function (err, resp, body) {
    if (!err && resp.statusCode == 200) {
      var token = body.access_token;
      // console.log(token);
      request.post(
      {
          uri: sso_service_url  + '/auth/admin/realms/' + realm + '/clients',
          strictSSL: false,
          auth: {
              bearer: token
          },
          json: {
              clientId: coolstore_client_id,
              enabled: true,
              protocol: "openid-connect",
              redirectUris: [
                  'http://' + coolstore_web_uri + '/*',
                  'https://' + coolstore_web_uri + '/*'
              ],
              webOrigins: [
                  "*"
              ],
              "bearerOnly": false,
              "publicClient": true
          }
      }, function (err, resp, body) {
          console.log("register client result: " + resp.statusCode + " " + resp.statusMessage + " " + JSON.stringify(body));
      });
    }
    else {
      console.error("Failed to fetch token with result " + ( err||resp.statusCode + " " + resp.statusMessage + " " + JSON.stringify(body) ));
      throw new Error('Faled to connect to SSO service using URL ' + sso_service_url + ', you might want to try again later.');
    }
  }
);
