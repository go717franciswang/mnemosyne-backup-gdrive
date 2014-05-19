require 'google/api_client'
require 'sinatra'
require 'logger'
require "yaml"
require 'inifile'

enable :sessions

def logger; settings.logger end
def api_client; settings.api_client; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('drive_auth.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG
  
  client = Google::APIClient.new({'application_name' => 'drive', 'application_version' => '0.01'})
  credential = IniFile.load(File.dirname(__FILE__) + '/config.ini')
  client.authorization.client_id = credential['main']['client_id']
  client.authorization.client_secret = credential['main']['client_secret']
  client.authorization.scope = 'https://www.googleapis.com/auth/drive.file'

  drive = client.discovered_api('drive', 'v2')

  set :logger, logger
  set :api_client, client
  set :drive, drive

  curdir = File.dirname(__FILE__)
  set :drive_token, File.join(curdir, 'drive_token.yaml')
end

before do
  # Ensure user has authorized the app
  unless user_credentials.access_token || request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at

  File.open(settings.drive_token, 'w') do |out|
    YAML.dump({
      'access_token' => user_credentials.access_token,
      'refresh_token' => user_credentials.refresh_token,
      'expires_in' => user_credentials.expires_in,
      'issued_at' => user_credentials.issued_at
    }, out)
  end
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

get '/' do
  result = api_client.execute(:api_method => settings.drive.about.get,
                              :authorization => user_credentials)
  [result.status, {'Content-Type' => 'application/json'}, result.data.to_json]
end
