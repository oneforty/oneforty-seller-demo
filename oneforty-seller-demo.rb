require 'rubygems'
require 'sinatra'

get '/' do
  "Hello from the oneforty demo store!"
end

not_found do
  "The page you're looking for is not part of the oneforty seller demo."
end

error do
  "Something went wrong. If you have questions about how to use this demo app, please let us know at developers@oneforty.com"
end