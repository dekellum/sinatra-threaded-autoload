#!/usr/bin/env jruby

# --
# Minimal example of threaded autoload problems on jruby, with
# sinatra and rack (which makes heavy use of autoload).
#
# jbundle install and run with:
#
# ./test.rb [-v] [thread_count]
#
# Where test_count of +1+ should always work properly.
# Note: Multiple cores may be required for it to fail.
#
# Author: David Kellum
#
# Public Domain
# ++

require 'rubygems'
require 'bundler/setup'

require 'thread'
require 'net/http'

require 'rjack-logback'

require 'sinatra/base'
require 'fishwife'

RJack::Logback.config_console( :stderr => true, :level => :info )

if ARGV.first == '-v'
  RJack::Logback.root.level = :debug
  ARGV.shift
end

# Only the 1 thread case makes this test reliable on jruby < 1.6.6
thread_count = ( ARGV.shift || 5 ).to_i

class TestApp < Sinatra::Base
  get '/' do
    "Threads are 'hard'"
  end
end

# Note: A workaround is to simply manually require +all+ used
# autoloads. Unfortunately that appears to be a moving target by app
# and sinatra/rack version i.e:
#
# require 'rack/builder'
# require 'rack/head'
# require 'rack/mime'
# require 'rack/nulllogger'
# require 'rack/protection/frame_options'
# require 'rack/protection/ip_spoofing'
# require 'rack/protection/json_csrf'
# require 'rack/protection/path_traversal'

# Start the server on any available port
server = Fishwife::HttpServer.new( :port => 0, :request_log_file => :stderr )
server.start( TestApp )

# Run simultaneous requests against the APP and log results
log = RJack::SLF4J['test']
ecode = 0
threads = thread_count.times.map do
  Thread.new( server.port ) do |port|
    res = Net::HTTP.start( 'localhost', port ) do |http|
      http.get( '/' )
    end
    if res.instance_of? Net::HTTPOK
      log.info  res.inspect
    else
      log.error res.inspect
      ecode = 1
    end

  end
end

threads.each { |t| t.join }

server.stop
server.join

exit ecode
