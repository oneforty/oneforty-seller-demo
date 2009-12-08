# Configure logging
log = File.new("log/sinatra.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

require 'oneforty-seller-demo'

run Sinatra::Application