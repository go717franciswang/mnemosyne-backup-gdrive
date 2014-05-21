### Dependencies
* google/api_client
* inifile

### Setup
1. Go to [Google API console] and set up "Client ID for native application"
1. "Download JSON" to project directory, and rename to client_secrets.json

### Use
* set folder_id, where you want backup/*.db synced to
* Run ```ruby sync.rb``` for the first time to manually authenticate
* set up crontab at appropriate times to sync regularly

### Development
* Use [APIs Explorer] to find out API method name and arguments

[Google API console]: https://code.google.com/apis/console
[APIs Explorer]: https://developers.google.com/apis-explorer/#p/drive/v2/
