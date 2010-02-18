require 'gcal4ruby/event'

module GCal4Ruby
#The Calendar Class is the representation of a Google Calendar.  Each user account 
#can have multiple calendars.  You must have an authenticated Service object before 
#using the Calendar object.
#=Usage
#All usages assume a successfully authenticated Service.
#1. Create a new Calendar
#    cal = Calendar.new(service)
#
#2. Find an existing Calendar
#    cal = Calendar.find(service, "New Calendar", :first)
#
#3. Find all calendars containing the search term
#    cal = Calendar.find(service, "Soccer Team")
#
#4. Find a calendar by ID
#    cal = Calendar.find(service, id, :first)
#
#After a calendar object has been created or loaded, you can change any of the 
#attributes like you would any other object.  Be sure to save the calendar to write changes
#to the Google Calendar service.

class Calendar
  CALENDAR_FEED = "http://www.google.com/calendar/feeds/default/owncalendars/full"
  
  #The calendar title
  attr_accessor :title
  
  #A short description of the calendar
  attr_accessor :summary
  
  #The parent Service object passed on initialization
  attr_reader :service
  
  #The unique calendar id
  attr_reader :id
  
  #Boolean value indicating the calendar visibility
  attr_accessor :hidden
  
  #The calendar timezone[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCaltimezone]
  attr_accessor :timezone
  
  #The calendar color.  Must be one of these[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCalcolor] values.
  attr_accessor :color
  
  #The calendar geo location, if any
  attr_accessor :where
  
  #A boolean value indicating whether the calendar appears by default when viewed online
  attr_accessor :selected
  
  #The event feed for the calendar
  attr_reader :event_feed
  
  #A flag indicating whether the calendar is editable by this account 
  attr_reader :editable
  
  #Returns true if the calendar exists on the Google Calendar system (i.e. was 
  #loaded or has been saved).  Otherwise returns false.
  def exists?
    return @exists
  end
  
  #Returns true if the calendar is publically accessable, otherwise returns false.
  def public?
    return @public
  end
  
  #Returns an array of Event objects corresponding to each event in the calendar.
  def events
    events = []
    ret = @service.send_get(@event_feed)
    REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns:app"] = "http://www.w3.org/2007/app"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      entry.attributes["xmlns:georss"] = "http://www.georss.org/georss"
      entry.attributes["xmlns:gml"] = "http://www.opengis.net/gml"
      e = Event.new(self)
      if e.load(entry.to_s)
        events << e
      end
    end
    return events
  end
  
  #Set the calendar to public (p = true) or private (p = false).  Publically viewable
  #calendars can be accessed by anyone without having to log in to google calendar.  See
  #Calendar#to_iframe for options to display a public calendar in a webpage.
  def public=(p)
    if p
      permissions = 'http://schemas.google.com/gCal/2005#read' 
    else
      permissions = 'none'
    end
    
    #if p != @public
      path = "http://www.google.com/calendar/feeds/#{@id}/acl/full/default"
      request = REXML::Document.new(ACL_XML)
      request.root.elements.each() do |ele|
        if ele.name == 'role'
          ele.attributes['value'] = permissions
        end
        
      end
      if @service.send_put(path, request.to_s, {"Content-Type" => "application/atom+xml", "Content-Length" => request.length.to_s})
        @public = p
        return true
      else
        return false
      end
    #end
  end

  #Accepts a Service object and an optional attributes hash for initialization.  Returns the new Calendar 
  #if successful, otherwise raises the InvalidService error.
  def initialize(service, attributes = {})
    super()
    if !service.is_a?(Service)
      raise InvalidService
    end
    attributes.each do |key, value|
      self.send("#{key}=", value)
    end
    @xml ||= CALENDAR_XML
    @service ||= service
    @exists = false
    @title ||= ""
    @summary ||= ""
    @public ||= false
    @hidden ||= false
    @timezone ||= "America/Los_Angeles"
    @color ||= "#2952A3"
    @where ||= ""
    return true
  end
  
  #Deletes a calendar.  If successful, returns true, otherwise false.  If successful, the
  #calendar object is cleared.
  def delete
    if @exists    
      if @service.send_delete(CALENDAR_FEED+"/"+@id)
        @exists = false
        @title = nil
        @summary = nil
        @public = false
        @id = nil
        @hidden = false
        @timezone = nil
        @color = nil
        @where = nil
        return true
      else
        return false
      end
    else
      return false
    end
  end
  
  #If the calendar does not exist, creates it, otherwise updates the calendar info.  Returns
  #true if the save is successful, otherwise false.
  def save
    if @exists
      ret = service.send_put(@edit_feed, to_xml(), {'Content-Type' => 'application/atom+xml'})
    else
      ret = service.send_post(CALENDAR_FEED, to_xml(), {'Content-Type' => 'application/atom+xml'})
    end
    if !@exists
      if load(ret.read_body)
        return true
      else
        raise CalendarSaveFailed
      end
    end
    return true
  end
  
  #Class method for querying the google service for specific calendars.  The service parameter
  #should be an appropriately authenticated Service. The term parameter can be any string.  The
  #scope parameter may be either :all to return an array of matches, or :first to return 
  #the first match as a Calendar object.
  def self.find(service, query_term=nil, params = {})
    t = query_term.downcase if query_term
    cals = service.calendars
    ret = []
    cals.each do |cal|
      title = cal.title || ""
      summary = cal.summary || ""
      id = cal.id || ""
      if id == query_term
        return cal
      end
      if title.downcase.match(t) or summary.downcase.match(t)
        if params[:scope] == :first
          return cal
        else
          ret << cal
        end
      end
    end
    ret
  end
  
  def self.get(service, id)
    url = 'http://www.google.com/calendar/feeds/default/allcalendars/full/'+id
    ret = service.send_get(url)
    puts "==return=="
    puts ret.body
  end
  
  def self.query(service, query_term)
    url = 'http://www.google.com/calendar/feeds/default/allcalendars/full'+"?q="+CGI.escape(query_term)
    ret = service.send_get(url)
    puts "==return=="
    puts ret.body
  end
  
  #Reloads the calendar objects information from the stored server version.  Returns true
  #if successful, otherwise returns false.  Any information not saved will be overwritten.
  def reload
    if not @exists
      return false
    end  
    t = Calendar.find(service, @id, :first)
    if t
      load(t.to_xml)
    else
      return false
    end
  end
  
  #Returns the xml representation of the Calenar.
  def to_xml
    xml = REXML::Document.new(@xml)
    xml.root.elements.each(){}.map do |ele|
      case ele.name
      when "title"
        ele.text = @title
      when "summary"
        ele.text = @summary
      when "timezone"
        ele.attributes["value"] = @timezone
      when "hidden"
        ele.attributes["value"] = @hidden.to_s
      when "color"
        ele.attributes["value"] = @color
      when "selected"
        ele.attributes["value"] = @selected.to_s
      end
    end
    xml.to_s
  end

  #Loads the Calendar with returned data from Google Calendar feed.  Returns true if successful.
  def load(string)
    @exists = true
    @xml = string
    xml = REXML::Document.new(string)
    xml.root.elements.each(){}.map do |ele|
      case ele.name
        when "id"
          @id = ele.text.gsub("http://www.google.com/calendar/feeds/default/calendars/", "")
        when 'title'
          @title = ele.text
        when 'summary'
          @summary = ele.text
        when "color"
          @color = ele.attributes['value']
        when 'hidden'
          @hidden = ele.attributes["value"] == "true" ? true : false
        when 'timezone'
          @timezone = ele.attributes["value"]
        when "selected"
          @selected = ele.attributes["value"] == "true" ? true : false
        when "link"
          if ele.attributes['rel'] == 'edit'
            @edit_feed = ele.attributes['href']
          end
      end
    end
    
    @event_feed = "http://www.google.com/calendar/feeds/#{@id}/private/full"
    
    if @service.check_public
      puts "Getting ACL Feed" if @service.debug
      
      #rescue error on shared calenar ACL list access
      begin 
        ret = @service.send_get("http://www.google.com/calendar/feeds/#{@id}/acl/full/")
      rescue Exception => e
        @public = false
        @editable = false
        return true
      end
      @editable = true
      r = REXML::Document.new(ret.read_body)
      r.root.elements.each("entry") do |ele|
        ele.elements.each do |e|
          #puts "e = "+e.to_s if @service.debug
          #puts "previous element = "+e.previous_element.to_s if @service.debug
          #added per eruder http://github.com/h13ronim/gcal4ruby/commit/3074ebde33bd3970500f6de992a66c0a4578062a
          if e.name == 'role' and e.previous_element and e.previous_element.name == 'scope' and e.previous_element.attributes['type'] == 'default'
            if e.attributes['value'].match('#read')
              @public = true
            else
              @public = false
            end
          end
        end
      end
    else
      @public = false
      @editable = true
    end
    return true
  end
  
  #Helper function to return the currently loaded calendar formatted iframe embedded google calendar.  
  #1. *params*: a hash of parameters that affect the display of the embedded calendar:
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
  def to_iframe(params = {})
    if not self.id
      raise "The calendar must exist and be saved before you can use this method."
    end
    params[:id] = self.id
    params[:height] ||= "600"
    params[:width] ||= "600"
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
    params.each do |key, value|
      case key
        when :height then output += "height=#{value}"
        when :width then output += "width=#{value}"
        when :title then output += "title=#{CGI.escape(value)}"
        when :bgcolor then output += "bgcolor=#{CGI.escape(value)}"
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
  
    output += "src=#{params[:id]}&amp;color=#{CGI.escape(params[:color])}"
        
    "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"  
  end
  
  #Helper function to return a specified calendar id as a formatted iframe embedded google calendar.  This function does not require loading the calendar information from the Google calendar
  #service, but does require you know the google calendar id. 
  #1. *id*: the unique google assigned id for the calendar to display.
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
  def self.to_iframe(id, params = {})
    params[:id] = id
    params[:height] ||= "600"
    params[:width] ||= "600"
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
    params.each do |key, value|
      case key
        when :height then output += "height=#{value}"
        when :width then output += "width=#{value}"
        when :title then output += "title=#{CGI.escape(value)}"
        when :bgcolor then output += "bgcolor=#{CGI.escape(value)}"
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
  
    output += "src=#{params[:id]}&amp;color=#{CGI.escape(params[:color])}"
        
    "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"  
  end

  private
  @xml 
  @exists = false
  @public = false
  @event_feed = ''
  @edit_feed = ''
  
end 

end