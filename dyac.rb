require 'rubygems'
require 'bundler/setup'
require 'net/http'
require 'uri'
require 'sinatra'
require 'nokogiri'
require 'haml'
require 'eventmachine'

require 'open-uri'
require 'system_timer'

set :views, File.dirname(__FILE__)

def scrape(html)
  doc = Nokogiri::XML html.gsub(/[^[:print:]]/, "")
  doc.css('#content .post .body p img')
end

def em_run
  finished, @errors, @images, pages = 0, [], [], 5

  EM.run do
    
    cleanup = Proc.new do
      finished += 1
      EM.stop if finished == pages
    end            
    
    pages.times do |num|
      uri = URI.parse 'http://damnyouautocorrect.com' + (num > 1 ? "/page/#{num}/" : "/")
      begin
        req = EM::Protocols::HttpClient2.connect(uri.host, 80).get(uri.request_uri)
        t_s = Time.now
        req.timeout(10)
        req.errback { cleanup.call }
        req.callback do |resp|
          @images += scrape(resp.content)
          cleanup.call
        end
      rescue Exception => e
        @errors << "couldn't read #{uri}: #{e}"
        cleanup.call
      end            
    end
    
  end
  
end

def serial_run
  finished, @errors, @images, pages = 0, [], [], 5

  pages.times do |num|
    uri = 'http://damnyouautocorrect.com' + (num > 0 ? "/page/#{num+1}/" : "/")
    begin
      SystemTimer.timeout(5) do
        @images += scrape open(uri).read
      end
    rescue Exception => e
      @errors << "couldn't read #{uri}: #{e}"
    end
  end
  
end

get '/' do
  @start_time = Time.now
  # em_run
  serial_run
  response['Cache-Control'] = 'public, max-age=3600'
  haml :index
end

get '/env' do
  content_type 'text/plain'
  env.to_yaml
end