require 'rubygems'
require 'sinatra'
require 'vendor/sinatra_run_later/run_later'

get '/' do
  "Hello from the oneforty demo store!"
end

post '/sale_notification' do
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
  # hit /fulfillment/acknowledgment via ssl with dev key and tranasaction #
  #       recieve order info in response
  # generate key info
  # hit /fulfillment/complete url via ssl with dev key, trans #, and license info
  #       recieve success in response
  # done
end