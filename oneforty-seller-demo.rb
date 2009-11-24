require 'rubygems'
require 'sinatra'
require 'net/https'
require 'uri'
require 'socket'
require 'openssl'

get '/' do
  "Hello from the oneforty demo store!"
end

get '/sale_notification' do
  begin
    status 200 # Tell oneforty that you're ready to process the order!
    "success!"
  
    # TODO need to set timeout for do_successful_fulfillment to execute.
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

def do_successful_fulfillment
  url_base = "dev.oneforty.com"
  params = {'reference_code'=>'32SDG56GA', 'developer_key'=>'ASFVEBB5362'}
  
  # hit /fulfillment/acknowledge via ssl with dev key and tranasaction #
  res = perform_acknowledge(url_base, params)
  
  if res.kind_of? Net::HTTPSuccess
    #TODO recieve order info in response
    puts res.body
    puts "OK!"
    
    # generate key info
    complete_params = params.merge({'licence_key'=>'FDHERHQDFW'})
    
    res = perform_success(url_base, complete_params)
    
    if res.kind_of? Net::HTTPSuccess
      # TODO recieve success in response
      puts res.body
      puts "DONE!"
    else
      puts res.body
      puts "COMPLETE ERROR!"
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
  #http.enable_post_connection_check = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE #OpenSSL::SSL::VERIFY_PEER
  store = OpenSSL::X509::Store.new
  store.set_default_paths
  http.cert_store = store
  res = http.start {
    http.post(url_path, params.collect{ |k, v| "#{k}=#{v}" }.join("&"))
  }
  
  return res
end