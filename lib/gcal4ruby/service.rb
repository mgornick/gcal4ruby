require 'gcal4ruby/base' 
require 'gcal4ruby/calendar'

module GCal4Ruby

#The service class is the main handler for all direct interactions with the 
#Google Calendar API.  A service represents a single user account.  Each user
#account can have multiple calendars, so you'll need to find the calendar you
#want from the service, using the Calendar#find class method.
#=Usage
#
#1. Authenticate
#    service = Service.new
#    service.authenticate("user@gmail.com", "password")
#
#2. Get Calendar List
#    calendars = service.calendars
#

class Service < Base
  #Convenience attribute contains the currently authenticated account name
  attr_accessor :account
      
  # The token returned by the Google servers, used to authorize all subsequent messages
  attr_accessor :auth_token
  
  # Determines whether GCal4Ruby ensures a calendar is public.  Setting this to false can increase speeds by 
  # 50% but can cause errors if you try to do something to a calendar that is not public and you don't have
  # adequate permissions
  attr_accessor :check_public
  
  #added auth type to account for differences in headers between ClientLogin and Authsub
  attr_accessor :auth_type
  
  #Accepts an optional attributes hash for initialization values
  def initialize(attributes = {})
    super()
    attributes.each do |key, value|
      self.send("#{key}=", value)
    end    
    @check_public ||= true
  end

  # The authenticate method passes the username and password to google servers.  
  # If authentication succeeds, returns true, otherwise raises the AuthenticationFailed error.
  def authenticate(username, password)
    ret = nil
    ret = send_post(AUTH_URL, "Email=#{username}&Passwd=#{password}&source=GCal4Ruby&service=cl&accountType=HOSTED_OR_GOOGLE")
    if ret.class == Net::HTTPOK
      @auth_token = ret.read_body.to_a[2].gsub("Auth=", "").strip
      @account = username
      @auth_type = 'ClientLogin'
      return true
    else
      raise AuthenticationFailed
    end
  end
  
  # added authsub authentication.  pass in the upgraded authsub token and the username/email address
  def authsub_authenticate(authsub_token, account)
    @auth_token = authsub_token
    @account = account
    @auth_type = 'AuthSub'
    return true
  end

  #Returns an array of Calendar objects for each calendar associated with 
  #the authenticated account.
  def calendars
    if not @auth_token
       raise NotAuthenticated
    end
    ret = send_get(CALENDAR_LIST_FEED+"?max-results=10000")
    cals = []
    REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns:app"] = "http://www.w3.org/2007/app"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      cal = Calendar.new(self)
      cal.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
      cals << cal
    end
    return cals
  end
  
  #Helper function to return a formatted iframe embedded google calendar.  Parameters are:
  #1. *cals*: either an array of calendar ids, or <em>:all</em> for all calendars, or <em>:first</em> for the first (usally default) calendar
  #2. *params*: a hash of parameters that affect the display of the embedded calendar:
  #   height:: the height of the embedded calendar in pixels
  #   width:: the width of the embedded calendar in pixels
  #   title:: the title to display
  #   bgcolor:: the background color.  Limited choices, see google docs for allowable values.
  #   color:: the color of the calendar elements.  Limited choices, see google docs for allowable values.
  #   showTitle:: set to 'false' to hide the title
  #   showDate:: set to 'false' to hide the current date
  #   showNav:: set to 'false to hide the navigation tools
  #   showPrint:: set to 'false' to hide the print icon
  #   showTabs:: set to 'false' to hide the tabs
  #   showCalendars:: set to 'false' to hide the calendars selection drop down
  #   showTimezone:: set to 'false' to hide the timezone selection
  #   border:: the border width in pixels
  #   dates:: a range of dates to display in the format of 'yyyymmdd/yyyymmdd'.  Example: 20090820/20091001
  #   privateKey:: use to display a private calendar.  You can find this key under the calendar settings pane of the Google Calendar website.
  #   colors:: a hash of calendar ids as key and color values as associated hash values.  Example: {'test@gmail.com' => '#7A367A'} 
  def to_iframe(cals, params = {})
    params[:height] ||= "600"
    params[:width] ||= "600"
    params[:title] ||= (self.account ? self.account : '')
    params[:bgcolor] ||= "#FFFFFF"
    params[:color] ||= "#2952A3"
    params[:showTitle] = params[:showTitle] == false ? "showTitle=0" : ''
    params[:showNav] = params[:showNav] == false ? "showNav=0" : ''
    params[:showDate] = params[:showDate] == false ? "showDate=0" : ''
    params[:showPrint] = params[:showPrint] == false ? "showPrint=0" : ''
    params[:showTabs] = params[:showTabs] == false ? "showTabs=0" : ''
    params[:showCalendars] = params[:showCalendars] == false ? "showCalendars=0" : ''
    params[:showTimezone] = params[:showTimezone] == false ? 'showTz=0' : ''
    params[:border] ||= "0"
    output = ''
    puts "params = #{params.inspect}" if self.debug
    params.each do |key, value|
      puts "key = #{key} and value = #{value}" if self.debug
      case key
        when :height then output += "height=#{value}"
        when :width then output += "width=#{value}"
        when :title then output += "title=#{CGI.escape(value)}"
        when :bgcolor then output += "bgcolor=#{CGI.escape(value)}"
        when :color then output += "color=#{CGI.escape(value)}"
        when :showTitle then output += value
        when :showDate then output += value
        when :showNav then output += value
        when :showPrint then output += value
        when :showTabs then output += value
        when :showCalendars then output += value
        when :showTimezone then output += value
        when :viewMode then output += "mode=#{value}"
        when :dates then output += "dates=#{CGI.escape(value)}"
        when :privateKey then output += "pvttk=#{value}"
      end
      output += "&amp;"
    end
    
    puts "output = #{output}" if self.debug
    
    if cals.is_a?(Array)
      for c in cals
        output += "src=#{c}&amp;"
        if params[:colors] and params[:colors][c]
          output += "color=#{CGI.escape(params[:colors][c])}&amp;"
        end
      end
    elsif cals == :all
      cal_list = calendars()
      for c in cal_list
        output += "src=#{c.id}&amp;"
      end
    elsif cals == :first
      cal_list = calendars()
      output += "src=#{cal_list[0].id}&amp;"
    end
        
    "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"
  end
end

end