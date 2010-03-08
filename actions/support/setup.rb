begin
  require 'httparty'
rescue LoadError
  $stderr.puts "Missing httparty gem. Please run 'gem install httparty'."
  exit 1
end

require 'lib/ncbo_exception'
require 'lib/ncbo_service'

begin
  require 'json'
rescue LoadError
  $stderr.puts "Missing json gem. Please run 'gem install json'."
  exit 1
end

require 'lib/crowd'

if CloudCrowd.node?
  puts CloudCrowd.actions
end