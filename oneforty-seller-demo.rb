require 'rubygems'
require 'sinatra'
require 'vendor/sinatra_run_later/run_later'

ONEFORTY_BASE = "https://dev.oneforty.com"

get '/' do
  "Hello from the oneforty demo store!"
end

post '/sale-notification' do
  begin
    reference_code = params[:reference_code] # Unique to fulfillment request
    version_code = params[:version_code] # Identifies oneforty sellable version
    
    # Process the fulfillment asynchronously.
    run_later do
      sleep 3 # Wait long enough for oneforty to receive this request before pinging oneforty to process it.
      do_successful_fulfillment reference_code, version_code
    end
    
    status 200 # Tell oneforty that you're ready to process the order!
    "success!"
  rescue e
    status 500 # Tell oneforty that something went wrong. We'll keep hitting you every so often until we get a 200.
    "failure :-("
  end
end

def do_successful_fulfillment(reference_code, version_code)
  puts "Processing fulfillment"
  puts "Reference code: " + reference_code.to_s
  puts "Version code: " + version_code.to_s
  
  
  # hit /fulfillment/acknowledgment via ssl with dev key and tranasaction #
  #       recieve order info in response
  # generate key info
  # hit /fulfillment/complete url via ssl with dev key, trans #, and license info
  #       recieve success in response
  # done
end