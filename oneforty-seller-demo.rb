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

configure :production, :development, :staging, :sandbox do
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
post '/notification' do
  begin
    @post_data = JSON.load(request.body.read.to_s)
    
    logger.info "Params: #{@post_data.inspect}"
    reference_code = @post_data["reference_code"]                             # Unique to fulfillment request
    edition_code = @post_data["edition_code"]                                 # Identifies oneforty sellable version
    action = @post_data["action"]                                             # What type of notification oneforty has sent
    reason = @post_data.has_key?("reason") ? @post_data["reason"] : nil       # Why the subscription was canceled (past_due or manual)
    
    process_notification(action, reference_code, edition_code, reason)

    status 200 
    "success!"
  rescue Exception => e
    puts e.message
    status 500
    "Failure: #{e.to_s}"
  end
end

post '/notification_asynchronous' do
  begin
    @post_data = JSON.load(request.body.read.to_s)
    
    logger.info "Params: #{@post_data.inspect}"
    reference_code = @post_data["reference_code"]                             # Unique to fulfillment request
    edition_code = @post_data["edition_code"]                                 # Identifies oneforty sellable version
    action = @post_data["action"]                                             # What type of notification oneforty has sent
    reason = @post_data.has_key?("reason") ? @post_data["reason"] : nil       # Why the subscription was canceled (past_due or manual)
    
    # Process the fulfillment asynchronously.
    run_later do
      sleep 3 # Wait long enough for oneforty to receive this request before pinging oneforty to process it.
      
      process_notification(action, reference_code, edition_code, reason)
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

def process_notification(action, reference_code, edition_code, reason)
  if action == "fulfillment_notification"
    do_fulfillment(reference_code, edition_code)
  elsif action == "fulfillment_void"
    do_void(reference_code, edition_code)
  elsif action == "fulfillment_subscription_canceled"
    do_subscription_canceled(reference_code, edition_code, reason)
  elsif action == "fulfillment_subscription_past_due"
    do_subscription_past_due(reference_code, edition_code)
  elsif action == "fulfillment_subscription_renewal"
    do_subscription_renewal(reference_code, edition_code)
  else
    # TODO unkown action
  end
end

# Do the work to process a fulfillment request
def do_fulfillment(reference_code, edition_code)
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
  
  # Includes: reference_code, edition_code, buyer_email, buyer_twitter_handle
  logger.info "Acknowledge response: #{data.inspect}"
    
  # Generate key info -- where app-specific code would go to handle
  # provisioning this buyer. Include a fake license key for now.
  complete_params = params.merge({'license_key' => 'FAKE_APP_KEY'})
  
  # Now ready to confirm the fulfillment was successful.
  res = perform_complete(URL_BASE, complete_params)

  if res.kind_of? Net::HTTPSuccess
    data = JSON.load(res.body)
    logger.info "Complete response: #{data.inspect}"
  else
    logger.error "Error during complete: #{res.body}"
  end
end

# Do the work to process a void notification
def do_void(reference_code, edition_code)
  logger.info "Processing void"
  logger.info "Reference code: #{reference_code}"
  logger.info "Edition code: #{edition_code}"

  # Complete Void
  logger.info "Perform void, cancel account and/or license key."
end

def do_subscription_canceled(reference_code, edition_code, reason)
  logger.info "Processing subscription canceled"
  logger.info "Reference code: #{reference_code}"
  logger.info "Edition code: #{edition_code}"
  logger.info "Reason: #{reason}"

  # Complete Cancel
  logger.info "Perform cancel subscription for user associated with reference_code"
end

def do_subscription_past_due(reference_code, edition_code)
  logger.info "Processing subscription past due"
  logger.info "Reference code: #{reference_code}"
  logger.info "Edition code: #{edition_code}"

  # Complete Past Due
  logger.info "Denote subscription for user associated with reference_code is past due. You will recieve a follow-up on the second attempt where you many need to cancel it."
end

def do_subscription_renewal(reference_code, edition_code)
  logger.info "Processing subscription renewed"
  logger.info "Reference code: #{reference_code}"
  logger.info "Edition code: #{edition_code}"

  # Complete Renewal
  logger.info "Potentially record that the subscription for user associated with reference_code was renewed."
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
    # http.post(url_path, params.collect{ |k, v| "#{k}=#{v}" }.join("&"))
    http.post(url_path, params.to_json)
  }
  
  return res
end