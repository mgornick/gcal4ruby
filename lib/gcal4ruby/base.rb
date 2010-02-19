require "rexml/document"
require "cgi"
require "uri"
require "net/http"
require "net/https"
require "open-uri"
require "nkf"
require "time"

Net::HTTP.version_1_2

# GCal4Ruby is a full featured wrapper for the google calendar API

# =Usage:

module GCal4Ruby
  
  CALENDAR_XML = "<entry xmlns='http://www.w3.org/2005/Atom' 
       xmlns:gd='http://schemas.google.com/g/2005' 
       xmlns:gCal='http://schemas.google.com/gCal/2005'>
  <title type='text'></title>
  <summary type='text'></summary>
  <gCal:timezone value=''></gCal:timezone>
  <gCal:hidden value=''></gCal:hidden>
  <gCal:color value=''></gCal:color>
  <gd:where rel='' label='' valueString=''></gd:where>
  </entry>"
  
  ACL_XML = "<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gAcl='http://schemas.google.com/acl/2007'>
                      <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/acl/2007#accessRule'/>
                       <gAcl:scope type='default'></gAcl:scope>
                       <gAcl:role value=''></gAcl:role>
                    </entry>"
                    
  EVENT_XML = "<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005'>
  <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/g/2005#event'></category>
  <title type='text'></title>
  <content type='text'></content>
  <gd:transparency value=''></gd:transparency>
  <gd:eventStatus value=''></gd:eventStatus>
  <gd:where valueString=''></gd:where>
  <gd:when startTime='' endTime=''></gd:when>
</entry>
  "
  
  class AuthenticationFailed < StandardError; end #:nodoc: all

  class NotAuthenticated < StandardError; end
    
  class InvalidService < StandardError; end
    
  class HTTPPostFailed < StandardError; end
    
  class HTTPPutFailed < StandardError; end
    
  class HTTPGetFailed < StandardError; end
    
  class HTTPDeleteFailed < StandardError; end
    
  class CalendarSaveFailed < StandardError; end
  
  class EventSaveFailed < StandardError; end
    
  class RecurrenceValueError < StandardError; end
    
  class CalendarNotEditable < StandardError; end
    
  class QueryParameterError < StandardError; end

  #The ProxyInfo class contains information for configuring a proxy connection

  class ProxyInfo
    attr_accessor :address, :port, :username, :password
    @address = nil
    @port = nil
    @username = nil
    @password = nil

    #The initialize function accepts four variables for configuring the ProxyInfo object.  
    #The proxy connection is initiated using the builtin Net::HTTP proxy support.

    def initialize(address, port, username=nil, password=nil)
      @address = address
      @port = port
      @username = username
      @password = password
    end
  end
  
  #The Base class includes the basic HTTP methods for sending and receiving 
  #messages from the Google Calendar API.  You shouldn't have to use this class 
  #directly, rather access the functionality through the Service subclass.

  class Base
    AUTH_URL = "https://www.google.com/accounts/ClientLogin"
    CALENDAR_LIST_FEED = "http://www.google.com/calendar/feeds/default/allcalendars/full"
    @proxy_info = nil
    @auth_token = nil
    @debug = false

    #Contains the ProxyInfo object for using a proxy server
    attr_accessor :proxy_info
    
    #If set to true, debug will dump all raw HTTP requests and responses
    attr_accessor :debug
    
    # Sends an HTTP POST request.  The header should be a hash of name/value pairs.  
    # Returns the Net::HTTPResponse object on succces, or raises the appropriate
    # error if a non 20x response code is received.
    def send_post(url, content, header=nil)
      header = auth_header(header)
      ret = nil
      location = URI.parse(url)
      puts "url = "+url if @debug
      ret = do_post(location, header, content)
      while ret.is_a?(Net::HTTPRedirection)
        puts "Redirect received, resending post" if @debug
        ret = do_post(ret['location'], header, content)
      end
      if ret.is_a?(Net::HTTPSuccess)
        puts "20x response received\nResponse: \n"+ret.read_body if @debug
        return ret
      else
        puts "invalid response received: "+ret.code if @debug
        raise HTTPPostFailed, ret.body
      end
    end
    
    def do_post(url, header, content)
      ret = nil
      if url.is_a?(String)
        location = URI.parse(url)
      else
        location = url
      end
      http = get_http_object(location)
      puts "Starting post\nHeader: #{header}\n" if @debug
      http.start do |ht|
        ret = ht.post(location.to_s, content, header)
      end
      return ret
    end
    
    # Sends an HTTP PUT request.  The header should be a hash of name/value pairs.  
    # Returns the Net::HTTPResponse object on succces, or raises the appropriate
    # error if a non 20x response code is received.
    def send_put(url, content, header=nil)
      header = auth_header(header)
      ret = nil
      location = URI.parse(url)
      puts "url = "+url if @debug
      ret = do_put(location, header, content)
      while ret.is_a?(Net::HTTPRedirection)
        puts "Redirect received, resending post" if @debug
        ret = do_put(ret['location'], header, content)
      end
      if ret.is_a?(Net::HTTPSuccess)
        puts "20x response received\nResponse: \n"+ret.read_body if @debug
        return ret
      else
        puts "invalid response received: "+ret.code if @debug
        raise HTTPPutFailed, ret.body
      end
    end
    
    def do_put(url, header, content)
      ret = nil
      if url.is_a?(String)
        location = URI.parse(url)
      else
        location = url
      end
      http = get_http_object(location)
      puts "Starting put\nHeader: #{header}\n" if @debug
      http.start do |ht|
        ret = ht.put(location.to_s, content, header)
      end
      return ret
    end

    # Sends an HTTP GET request.  The header should be a hash of name/value pairs.  
    # Returns the Net::HTTPResponse object on succces, or raises the appropriate
    # error if a non 20x response code is received.
    def send_get(url, header = nil)
      header = auth_header(header)
      ret = nil
      location = URI.parse(url)
      puts "url = "+url if @debug
      ret = do_get(location, header)
      while ret.is_a?(Net::HTTPRedirection)
        puts "Redirect received from #{location.to_s}, resending get to #{ret['location']}" if @debug
        ret = do_get(ret['location'], header)
      end
      if ret.is_a?(Net::HTTPSuccess)
        puts "20x response received\nResponse: \n"+ret.read_body if @debug
        return ret
      else
        puts "Error received, resending get" if @debug
        raise HTTPGetFailed, ret.body
      end
    end
    
    def do_get(url, header)
      ret = nil
      if url.is_a?(String)
        location = URI.parse(url)
      else
        location = url
      end
      http = get_http_object(location)
      puts "Starting get\nHeader: #{header}\n" if @debug
      http.start do |ht|
        ret = ht.get(location.to_s, header)
      end
      return ret
    end

    # Sends an HTTP DELETE request.  The header should be a hash of name/value pairs.  
    # Returns the Net::HTTPResponse object on succces, or raises the appropriate
    # error if a non 20x response code is received.
    def send_delete(url, header = nil)
      header = auth_header(header)
      ret = nil
      location = URI.parse(url)
      puts "url = "+url if @debug
      ret = do_delete(location, header)
      while ret.is_a?(Net::HTTPRedirection)
        puts "Redirect received, resending post" if @debug
        ret = do_delete(ret['location'], header)
      end
      if ret.is_a?(Net::HTTPSuccess)
        puts "20x response received\nResponse: \n"+ret.read_body if @debug
        return true
      else
        puts "invalid response received: "+ret.code if @debug
        raise HTTPDeleteFailed, ret.body
      end
    end
    
    def do_delete(url, header)
      ret = nil
      if url.is_a?(String)
        location = URI.parse(url)
      else
        location = url
      end
      http = get_http_object(location)
      puts "Starting get\nHeader: #{header}\n" if @debug
      http.start do |ht|
        ret = ht.delete(location.to_s, header)
      end
      return ret
    end

    private

    def get_http_object(location)
      if @proxy_info and @proxy_info.address
	     http = Net::HTTP.new(location.host, location.port, @proxy_info.address, @proxy_info.port, @proxy_info.username, @proxy_info.password)
      else
	     http = Net::HTTP.new(location.host, location.port)
	    end
      if location.scheme == 'https'
        #fixed http/http misnaming via JohnMetta
        puts "SSL True" if @debug
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      return http
    end

    def auth_header_client_login(header)
      if @auth_token
        if header
          header.merge!({'Authorization' => "GoogleLogin auth=#{@auth_token}", "GData-Version" => "2.1"})
        else 
          header = {'Authorization' => "GoogleLogin auth=#{@auth_token}", "GData-Version" => "2.1"}
        end
      end
      
      return header
    end
    
    #auth header that uses google authsub 
    def auth_header_authsub(header)
      if @auth_token
      	if header
      	  header.merge!({'Authorization' => "AuthSub token=#{@auth_token}", "GData-Version" => "2.1"})
      	else 
      	  header = {'Authorization' => "AuthSub token=#{@auth_token}", "GData-Version" => "2.1"}
      	end
      end
      return header
    end
    
    # routes the authentication to the proper header based upon auth type
    def auth_header_authsub(header)
      if @auth_type == 'AuthSub'
        return auth_header_authsub(header)
      elsif @auth_type == 'ClientLogin'
        return auth_header_client_login(header)
      end
    end
    
  end
end