require 'google/api_client'
require 'inifile'
require 'json'
require 'yaml'

curdir = File.dirname(__FILE__)
client = Google::APIClient.new({'application_name' => 'drive', 'application_version' => '0.01'})
config = IniFile.load(File.join(curdir, 'config.ini'))
client.authorization.client_id = config['main']['client_id']
client.authorization.client_secret = config['main']['client_secret']
client.authorization.scope = 'https://www.googleapis.com/auth/drive'
drive = client.discovered_api('drive', 'v2')

access_token = File.join(curdir, 'drive_token.yaml')
session = YAML.load_file(access_token)
client.authorization.update_token!(session)

result = client.execute(
  api_method: drive.children.list,
  parameters: {
    folderId: config['main']['folder_id']
  }
)

rs = JSON.load(result.body)
rs['items'].each do |item|
  id = item['id']
  result = client.execute(
    api_method: drive.files.get,
    parameters: {
      fileId: id
    }
  )
  rs2 = JSON.load(result.body)
  title = rs2['title']
  md5 = rs2['md5Checksum']
  modified = rs2['modifiedDate']
  puts "#{id}, #{title}, #{md5}, #{modified}"
end

session[:access_token] = client.authorization.access_token
session[:refresh_token] = client.authorization.refresh_token
session[:expires_in] = client.authorization.expires_in
session[:issued_at] = client.authorization.issued_at
File.open(access_token, 'w') do |out|
  YAML.dump(session, out)
end


