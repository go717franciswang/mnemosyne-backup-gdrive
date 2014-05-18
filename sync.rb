require 'google/api_client'
require 'inifile'
require 'json'
require 'yaml'
require 'digest'
require 'set'

curdir = File.dirname(__FILE__)
config = IniFile.load(File.join(curdir, 'config.ini'))

client = Google::APIClient.new({'application_name' => 'drive', 'application_version' => '0.01'})
client.authorization.client_id = config['main']['client_id']
client.authorization.client_secret = config['main']['client_secret']
client.authorization.scope = 'https://www.googleapis.com/auth/drive/file'
drive = client.discovered_api('drive', 'v2')

access_token = File.join(curdir, 'drive_token.yaml')
session = YAML.load_file(access_token)
client.authorization.update_token!(session)

result = client.execute(
  api_method: drive.children.list,
  parameters: {
    folderId: config['main']['google_drive_folder_id']
  }
)

gdrive_file_info = {}
rs = JSON.load(result.body)
rs['items'].each do |item|
  id = item['id']
  result = client.execute(
    api_method: drive.files.get,
    parameters: {
      fileId: id
    }
  )
  info = JSON.load(result.body)
  title = info['title']
  gdrive_file_info[title] = info
end

# if google drive contain the file and md5 matches, no change
# if google drive contain the file and md5 does not match, update
# if google drive does not contain the file, upload

local_files = Set.new
Dir.glob(File.join(config['main']['local_backup_dir'], '*.db')).each do |filepath|
  filename = File.basename(filepath)
  local_files.add(filename)
  if gdrive_file_info.has_key?(filename)
    md5 = Digest::MD5.file(filepath).hexdigest
    if md5 != gdrive_file_info[filename]['md5Checksum']
      puts "#{filename} md5 does not match, will update"
      # https://developers.google.com/drive/v2/reference/files/update
      mimetype = 'application/octet-stream'
      file = drive.files.update.request_schema.new({
        'title' => filename,
        'description' => 'mnemosyne backup',
        'mimeType' => mimetype,
        'parents' => [{'id' => config['main']['google_drive_folder_id']}]
      })

      media = Google::APIClient::UploadIO.new(filepath, mimetype)
      result = client.execute(
        :api_method => drive.files.update,
        :body_object => file,
        :media => media,
        :parameters => {
          'uploadType' => 'multipart',
          'alt' => 'json'
        }
      )
    else
      puts "#{filename} md5 matches, no need to update"
    end
  else
    puts "#{filename} does not exist on google drive, will upload"
    # https://developers.google.com/drive/web/quickstart/quickstart-ruby#step_4_run_the_sample
    # https://developers.google.com/drive/v2/reference/files/insert
    mimetype = 'application/octet-stream'
    file = drive.files.insert.request_schema.new({
      'title' => filename,
      'description' => 'mnemosyne backup',
      'mimeType' => mimetype,
      'parents' => [{'id' => config['main']['google_drive_folder_id']}]
    })

    media = Google::APIClient::UploadIO.new(filepath, mimetype)
    result = client.execute(
      :api_method => drive.files.insert,
      :body_object => file,
      :media => media,
      :parameters => {
        'uploadType' => 'multipart',
        'alt' => 'json'
      }
    )
  end
end

session[:access_token] = client.authorization.access_token
session[:refresh_token] = client.authorization.refresh_token
session[:expires_in] = client.authorization.expires_in
session[:issued_at] = client.authorization.issued_at
File.open(access_token, 'w') do |out|
  YAML.dump(session, out)
end
