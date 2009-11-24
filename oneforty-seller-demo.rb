require 'rubygems'
require 'sinatra'
require 'net/https'
require 'uri'
require 'socket'
require 'openssl'
require 'json'
require 'vendor/sinatra_run_later/run_later'

DEVELOPER_KEY = '962BF0935EDD90E64AAE4260793A4634756B5047'
URL_BASE = "dev.oneforty.com"

get '/' do
  "Hello from the oneforty demo store!"
end

post '/sale_notification' do
  begin
    reference_code = params[:reference_code] # Unique to fulfillment request
    version_code = params[:version_code] # Identifies oneforty sellable version
    
    # Process the fulfillment asynchronously.
    run_later do
      sleep 3 # Wait long enough for oneforty to receive this request before pinging oneforty to process it.
      do_successful_fulfillment(reference_code, version_code)
    end
    
    status 200 # Tell oneforty that you're ready to process the order!
    "success!"
  rescue e
    status 500 # Tell oneforty that something went wrong. We'll keep hitting you every so often until we get a 200.
    "failure :-("
  end
end

not_found do
  "The page you're looking for is not part of the oneforty seller demo."
end

error do
  "Something went wrong. If you have questions about how to use this demo app, please let us know at developers@oneforty.com"
end

def do_successful_fulfillment(reference_code, version_code)
  puts "Processing fulfillment"
  puts "Reference code: #{reference_code}"
  puts "Version code: #{version_code}"

  params = {'reference_code'=>reference_code, 'developer_key'=>DEVELOPER_KEY}
  
  # hit /fulfillment/acknowledge via ssl with dev key and tranasaction #
  res = perform_acknowledge(URL_BASE, params)
  
  if res.kind_of? Net::HTTPSuccess
    puts res.body
    puts "OK!"
    
    # parse order info in response
    data = JSON.load(res.body)
    
    puts "Reference code: #{data['reference_code']}"
    puts "Version code: #{data['sellable_version']}"
    puts "Buyer email: #{data['buyer_email']}"
    puts "Buyer twitter handle: #{data['buyer_twitter_handle']}"
    
    # generate key info
    complete_params = params.merge({'license_key'=>'FDHERHQDFW'})
    res = perform_complete(URL_BASE, complete_params)

    if res.kind_of? Net::HTTPSuccess
      puts res.body
      puts "DONE!"
      
      # TODO recieve success in response
      data = JSON.load(res.body)
    else
      puts res.body
      puts "COMPLETE ERROR (much like freerobby)!"
    end
  else
    puts res.body
    puts "AWK ERROR!"
  end
end

def perform_acknowledge(url_base, params)
  return do_request(url_base, "/fulfillment/acknowledge", params)
end

def perform_complete(url_base, params)  
  return do_request(url_base, "/fulfillment/complete", params)
end

def do_request(url_base, url_path, params)
  #######
  # DO NOT DELETE
  #######
  # http = Net::HTTPS.new(url_base, 443)
  # http.use_ssl = true
  # http.enable_post_connection_check = true
  # http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  # store = OpenSSL::X509::Store.new
  # store.set_default_paths
  # http.cert_store = store
  # http.start {
  #   res = http.post("fulfillment/acknowledge")
  #   p res.body
  # }
  
  # socket = TCPSocket.new("dev.oneforty.com", 443) 
  # ssl_context = OpenSSL::SSL::SSLContext.new() 
  # 
  # unless ssl_context.verify_mode
  #   warn "warning: peer certificate won't be verified this session."
  #   ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE 
  # end
  # 
  # sslsocket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context) 
  # sslsocket.sync_close = true 
  # sslsocket.connect 
  # sslsocket.puts("POST /fulfillment/acknowledge")
  # 
  # while line = sslsocket.gets 
  #   p line
  # end
  
  http = Net::HTTP.new(url_base, 443)
  http.use_ssl = true
  # http.enable_post_connection_check = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE #OpenSSL::SSL::VERIFY_PEER    
  store = OpenSSL::X509::Store.new 
  store.set_default_paths  
  http.cert_store = store
  
  res = http.start {
    http.post(url_path, params.collect{ |k, v| "#{k}=#{v}" }.join("&"))
  }
  
  return res
end