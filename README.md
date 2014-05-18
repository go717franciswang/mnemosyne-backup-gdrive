### Dependencies
* google/api_client
* sinatra
* inifile

### Setup
1. go to [Google API console] and set up "Client ID for web applications"
1. copy and paste "Client ID" and "Client secret" to config.ini
1. set "Redirect URIs" to http://localhost:4567/oauth2callback, which is the callback page OAuth redirects to. This page is temporarily hosted on Sinatra. It is used to capture the access_token, which is stored in drive_token.yaml
1. start Sinatra server, ```ruby authorize.rb```
1. visit http://localhost:4567
1. check if drive_token.yaml is generated and has access token
1. (might need to comment out the first line of drive_token.yaml, only access_token and refresh_token are pertinent)

### Development
* Use [APIs Explorer] to find out API method name and arguments

[Google API console]: https://code.google.com/apis/console
[APIs Explorer]: https://developers.google.com/apis-explorer/#p/drive/v2/
