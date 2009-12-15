require 'rubygems'
require 'sinatra'
require 'net/https'
require 'uri'
require 'socket'
require 'openssl'
require 'json'
require 'logger'
require 'vendor/sinatra_run_later/run_later'

# Sinatra config
set :logging, true

RunLater.run_now = true

configure do 
  LOGGER = Logger.new("log/sinatra.log")
  
  # Hard-coded fake developer key
  DEVELOPER_KEY = 'FAKE_DEV_KEY_1234'
  # Where to find SSL ca
  ROOT_CA = '/etc/ssl/certs'
end

configure :production, :development, :staging do
  # Base URL for testing
  URL_BASE = "sandbox.oneforty.com"
end

# Start like: ruby oneforty-seller-demo.rb -e local
configure :local do
  # For internal testing
  URL_BASE = "dev.oneforty.com"
end

helpers do
  def logger
    LOGGER
  end
end


## Actions

# Used to confirm example app is running
get '/' do
  msg = "Hello from the oneforty example seller app!"
  logger.info(msg)
  msg
end

# The standard flow to complete a sale. This is the URL that would be entered on oneforty.
post '/sale_notification' do
  begin
    logger.info "Params: #{params.inspect}"
    reference_code = params[:reference_code]          # Unique to fulfillment request
    edition_code = params[:edition_code]              # Identifies oneforty sellable version
    
    do_successful_fulfillment(reference_code, edition_code)

    status 200 
    "success!"
  rescue Exception => e
    puts e.message
    status 500
    "Failure: #{e.to_s}"
  end
end

post '/sale_notification_asynchronous' do
  begin
    logger.info "Params: #{params.inspect}"
    reference_code = params[:reference_code]          # Unique to fulfillment request
    edition_code = params[:edition_code]              # Identifies oneforty sellable version
    
    # Process the fulfillment asynchronously.
    run_later do
      sleep 3 # Wait long enough for oneforty to receive this request before pinging oneforty to process it.
      do_successful_fulfillment(reference_code, edition_code)
    end
    
    status 200
    "success!"
  rescue Exception => e
    puts e.message
    status 500
    "Failure: #{e.to_s}"
  end
end

not_found do
  "The page you're looking for is not part of the oneforty seller demo."
end

error do
  "Something went wrong. If you have questions about how to use this demo app, please let us know at developers@oneforty.com"
end

# Do the work to process a fulfillment request
def do_successful_fulfillment(reference_code, edition_code)
  logger.info "Processing fulfillment"
  logger.info "Reference code: #{reference_code}"
  logger.info "Edition code: #{edition_code}"

  params = {'reference_code' => reference_code, 'developer_key' => DEVELOPER_KEY}
  
  # Hit /fulfillment/acknowledge via SSL with dev key and tranasaction number
  # to find out who purchased our application
  res = perform_acknowledge(URL_BASE, params)
  
  if !res.kind_of? Net::HTTPSuccess
    logger.error "Error during awknowledge (#{res.code}): #{res.body}"
    raise Exception.new res.inspect.to_s
  end
  
  # Parse order info in response
  data = JSON.load(res.body)
  
  logger.info "Reference code: #{data['reference_code']}"
  logger.info "Edition code: #{data['edition_code']}"
  logger.info "Buyer email: #{data['buyer_email']}"
  logger.info "Buyer twitter handle: #{data['buyer_twitter_handle']}"
  
  # Generate key info -- where app-specific code would go to handle
  # provisioning this buyer. Include a fake license key for now.
  complete_params = params.merge({'license_key' => 'FAKE_APP_KEY'})
  
  # Now ready to confirm the fulfillment was successful.
  res = perform_complete(URL_BASE, complete_params)

  if res.kind_of? Net::HTTPSuccess
    data = JSON.load(res.body)
  else
    logger.error "Error during complete: #{res.body}"
  end
end

def perform_acknowledge(url_base, params)
  return do_request(url_base, "/fulfillment/acknowledge", params)
end

def perform_complete(url_base, params)  
  return do_request(url_base, "/fulfillment/complete", params)
end

# Make the actual request over SSL
def do_request(url_base, url_path, params)
  logger.info "Base: #{url_base} Path: #{url_path} Params: #{params.inspect}"  
  http = Net::HTTP.new(url_base, 443)
  http.use_ssl = true
  
  # http://redcorundum.blogspot.com/2008/03/ssl-certificates-and-nethttps.html
  if File.exist? ROOT_CA
   http.ca_file = ROOT_CA
   http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   http.verify_depth = 5
  else
    logger.error "Failed to find root certificate authority"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  
  # http.enable_post_connection_check = true
  store = OpenSSL::X509::Store.new 
  store.set_default_paths  
  http.cert_store = store
  
  res = http.start {
    http.post(url_path, params.collect{ |k, v| "#{k}=#{v}" }.join("&"))
  }
  
  return res
end