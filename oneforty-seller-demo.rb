require 'rubygems'
require 'sinatra'

get '/' do
  "Hello from the oneforty demo store!"
end

# Process an ORDER ACKNOWLEDGMENT from oneforty.
# A POST to this URL from oneforty alerts you that you have just made a sale.
# You should respond with status 200 if you are ready to process it, or status 500 if your processing system is down.
# If you respond with status 500, we will keep retrying every so often until we get a status 200.
post '/order-acknowledgment' do
  begin
    status 200 # Tell oneforty that you're ready to process the order!
    "success!"
    # You now need to ping us back over SSL so that we can exchange sensitive data.
  rescue e
    status 500 # Tell oneforty that something went wrong. We'll keep hitting you every so often until we get a 200.
    "failure :-("
  end
end

get '/order-acknowledgment' do
  "Sorry, GET requests are not supported for order acknowledgments!"
end

not_found do
  "The page you're looking for is not part of the oneforty seller demo."
end

error do
  "Something went wrong. If you have questions about how to use this demo app, please let us know at developers@oneforty.com"
end