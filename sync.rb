# Copyright (C) 2012 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'
require 'logger'
require 'inifile'

API_VERSION = 'v2'
CACHED_API_FILE = "drive-#{API_VERSION}.cache"
CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

# Handles authentication and loading of the API.
def setup()
  log_file = File.open('drive.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new(:application_name => 'Ruby Drive sample',
      :application_version => '1.0.0')

  # FileStorage stores auth credentials in a file, so they survive multiple runs
  # of the application. This avoids prompting the user for authorization every
  # time the access token expires, by remembering the refresh token.
  # Note: FileStorage is not suitable for multi-user applications.
  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    # The InstalledAppFlow is a helper class to handle the OAuth 2.0 installed
    # application flow, which ties in with FileStorage to store credentials
    # between runs.
    flow = Google::APIClient::InstalledAppFlow.new(
      :client_id => client_secrets.client_id,
      :client_secret => client_secrets.client_secret,
      :scope => ['https://www.googleapis.com/auth/drive']
    )
    client.authorization = flow.authorize(file_storage)
  else
    client.authorization = file_storage.authorization
  end

  drive = nil
  # Load cached discovered API, if it exists. This prevents retrieving the
  # discovery document on every run, saving a round-trip to API servers.
  if File.exists? CACHED_API_FILE
    File.open(CACHED_API_FILE) do |file|
      drive = Marshal.load(file)
    end
  else
    drive = client.discovered_api('drive', API_VERSION)
    File.open(CACHED_API_FILE, 'w') do |file|
      Marshal.dump(drive, file)
    end
  end

  return client, drive
end

# Handles files.insert call to Drive API.
def get_grive_file_info(client, drive, config)
  gdrive_file_info = {}

  result = client.execute(
    api_method: drive.children.list,
    parameters: {
      folderId: config['main']['google_drive_folder_id']
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
    info = JSON.load(result.body)
    title = info['title']
    gdrive_file_info[title] = info
  end

  gdrive_file_info
end

def update_file(client, drive, filepath, config)
  # https://developers.google.com/drive/v2/reference/files/update
  filename = File.basename(filepath)
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
end

def insert_file(client, drive, filepath, config)
  # https://developers.google.com/drive/web/quickstart/quickstart-ruby#step_4_run_the_sample
  # https://developers.google.com/drive/v2/reference/files/insert
  filename = File.basename(filepath)
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


if __FILE__ == $0
  client, drive = setup()
  curdir = File.dirname(__FILE__)
  config = IniFile.load(File.join(curdir, 'config.ini'))

  gdrive_file_info = get_grive_file_info(client, drive, config)

  local_files = Set.new
  Dir.glob(File.join(config['main']['local_backup_dir'], '*.db')).each do |filepath|
    filename = File.basename(filepath)
    if gdrive_file_info.has_key?(filename)
      md5 = Digest::MD5.file(filepath).hexdigest
      if md5 != gdrive_file_info[filename]['md5Checksum']
        puts "#{filename} md5 does not match, will update"
        update_file(client, drive, filepath, config)
      else
        puts "#{filename} md5 matches, no need to update"
      end
    else
      puts "#{filename} does not exist on google drive, will upload"
      insert_file(client, drive, filepath, config)
    end
  end
end

