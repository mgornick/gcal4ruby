require 'gcal4ruby/recurrence'

module GCal4Ruby
  #The Event Class represents a remote event in calendar. 
  #
  #=Usage
  #All usages assume a successfully authenticated Service and valid Calendar.
  #1. Create a new Event
  #    event = Event.new(calendar)
  #    event.title = "Soccer Game"
  #    event.start = Time.parse("12-06-2009 at 12:30 PM")
  #    event.end = Time.parse("12-06-2009 at 1:30 PM")
  #    event.where = "Merry Playfields"
  #    event.save
  #
  #2. Find an existing Event
  #    event = Event.find(cal, "Soccer Game", {:scope => :first})
  #
  #3. Find all events containing the search term
  #    event = Event.find(cal, "Soccer Game")
  #
  #4. Create a recurring event for every saturday
  #    event = Event.new(calendar)
  #    event.title = "Baseball Game"
  #    event.where = "Municipal Stadium"
  #    event.recurrence = Recurrence.new
  #    event.recurrence.start = Time.parse("13-06-2009 at 4:30 PM")
  #    event.recurrence.end = Time.parse("13-06-2009 at 6:30 PM")
  #    event.recurrence.frequency = {"weekly" => ["SA"]}
  #    event.save 
  #
  #5. Create an event with a 15 minute email reminder
  #    event = Event.new(calendar)
  #    event.title = "Dinner with Kate"
  #    event.start = Time.parse("20-06-2009 at 5 pm")
  #    event.end = Time.parse("20-06-209 at 8 pm")
  #    event.where = "Luigi's"
  #    event.reminder = {:minutes => 15, :method => 'email'}
  #    event.save
  #
  #6. Create an event with attendees
  #    event = Event.new(calendar)
  #    event.title = "Dinner with Kate"
  #    event.start = Time.parse("20-06-2009 at 5 pm")
  #    event.end = Time.parse("20-06-209 at 8 pm")
  #    event.attendees => {:name => "Kate", :email => "kate@gmail.com"}
  #    event.save
  #
  #After an event object has been created or loaded, you can change any of the 
  #attributes like you would any other object.  Be sure to save the event to write changes
  #to the Google Calendar service.
  class Event
    #The event title
    attr_accessor :title
    #The content for the event
    attr_accessor :content
    #The location of the event
    attr_accessor :where
    #A flag for whether the event show as :free or :busy
    attr_accessor :transparency
    #A flag indicating the status of the event.  Values can be :confirmed, :tentative or :cancelled
    attr_accessor :status
    #The unique event ID
    attr_accessor :id
    #Flag indicating whether it is an all day event
    attr_accessor :all_day
    
    @attendees
    
    #The event start time
    attr_reader :start
    #The event end time
    attr_reader :end
    #The reminder settings for the event, returned as a hash
    attr_reader :reminder
    #The date the event was created
    attr_reader :published
    #The date the event was last updated
    attr_reader :updated
    #The date the event was last edited
    attr_reader :edited
    
    #Sets the reminder options for the event.  Parameter must be a hash containing one of 
    #:hours, :minutes and :days, which are simply the number of each before the event start date you'd like to 
    #receive the reminder.  
    #
    #:method can be one of the following:
    #- <b>'alert'</b>: causes an alert to appear when a user is viewing the calendar in a browser
    #- <b>'email'</b>: sends the user an email message
    def reminder=(r)
      @reminder = r
    end
    
    #Returns the current event's Recurrence information
    def recurrence
      @recurrence
    end
    
    #Returns an array of the current attendees
    def attendees
      @attendees
    end
    
    #Accepts an array of email address/name pairs for attendees.  
    #  [{:name => 'Mike Reich', :email => 'mike@seabourneconsulting.com'}]
    #The email address is requried, but the name is optional
    def attendees=(a)
      if a.is_a?(Array)
        @attendees = a
      else
        raise "Attendees must be an Array of email/name hash pairs"
      end
    end
    
    #Sets the event's recurrence information to a Recurrence object.  Returns the recurrence if successful,
    #false otherwise
    def recurrence=(r)
      if r.is_a?(Recurrence) or r.nil?
        r.event = self unless r.nil?
        @recurrence = r
      else
        return false
      end
    end
    
    #Returns a duplicate of the current event as a new Event object
    def copy()
      e = Event.new()
      e.load(to_xml)
      e.calendar = @calendar
      return e
    end
    
    #Sets the start time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def start=(str)
      if str.is_a?String
        @start = Time.parse(str)      
      elsif str.is_a?Time
        @start = str
      else
        raise "Start Time must be either Time or String"
      end
    end
    
    #Sets the end time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def end=(str)
      if str.is_a?String
        @end = Time.parse(str)      
      elsif str.is_a?Time
        @end = str
      else
        raise "End Time must be either Time or String"
      end
    end
    
    #Deletes the event from the Google Calendar Service.  All values are cleared.
    def delete
        if @exists    
          if @calendar.service.send_delete(@edit_feed, {"If-Match" => @etag})
            @exists = false
            @deleted = true
            @title = nil
            @content = nil
            @id = nil
            @start = nil
            @end = nil
            @transparency = nil
            @status = nil
            @where = nil
            return true
          else
            return false
          end
        else
          return false
        end
    end
    
    #Creates a new Event.  Accepts a valid Calendar object and optional attributes hash.
    def initialize(calendar, attributes = {})
      if not calendar.editable
        raise CalendarNotEditable
      end
      super()
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
      @xml ||= EVENT_XML
      @calendar ||= calendar
      @transparency ||= "http://schemas.google.com/g/2005#event.opaque"
      @status ||= "http://schemas.google.com/g/2005#event.confirmed"
      @attendees ||= []
      @all_day ||= false
    end
    
    #If the event does not exist on the Google Calendar service, save creates it.  Otherwise
    #updates the existing event data.  Returns true on success, false otherwise.
    def save
      if @deleted
        return false
      end
      if @exists 
        ret = @calendar.service.send_put(@edit_feed, to_xml, {'Content-Type' => 'application/atom+xml', "If-Match" => @etag})
      else
        ret = @calendar.service.send_post(@calendar.event_feed, to_xml, {'Content-Type' => 'application/atom+xml'})
      end
      if !@exists
        if load(ret.read_body)
          return true
        else
          raise EventSaveFailed
        end
      end
      reload
      return true
    end
    
    #Returns an XML representation of the event.
    def to_xml()
      xml = REXML::Document.new(@xml)
      xml.root.elements.each(){}.map do |ele|
        case ele.name
        when 'id'
          ele.text = @id
        when "title"
          ele.text = @title
        when "content"
          ele.text = @content
        when "when"
          if not @recurrence
            ele.attributes["startTime"] = @all_day ? @start.strftime("%Y-%m-%d") : @start.xmlschema
            ele.attributes["endTime"] = @all_day ? @end.strftime("%Y-%m-%d") : @end.xmlschema
            set_reminder(ele)
          else
            if not @reminder
              xml.root.delete_element("/entry/gd:when")
              xml.root.add_element("gd:recurrence").text = @recurrence.to_s
            else
              ele.delete_attribute('startTime')
              ele.delete_attribute('endTime')
              set_reminder(ele)  
            end
          end
        when "eventStatus"
          ele.attributes["value"] = case @status
            when :confirmed
              "http://schemas.google.com/g/2005#event.confirmed"
            when :tentative
              "http://schemas.google.com/g/2005#event.tentative"
            when :cancelled
              "http://schemas.google.com/g/2005#event.canceled"
            else
              "http://schemas.google.com/g/2005#event.confirmed"
          end
        when "transparency"
          ele.attributes["value"] = case @transparency
              when :free
                "http://schemas.google.com/g/2005#event.transparent"
              when :busy
                "http://schemas.google.com/g/2005#event.opaque"
              else
                "http://schemas.google.com/g/2005#event.opaque"
            end
        when "where"
          ele.attributes["valueString"] = @where
        when "recurrence"
          puts 'recurrence element found' if @calendar.service.debug
          if @recurrence
            puts 'setting recurrence' if @calendar.service.debug
            ele.text = @recurrence.to_s
          else
            puts 'no recurrence, adding when' if @calendar.service.debug
            w = xml.root.add_element("gd:when")
            xml.root.delete_element("/entry/gd:recurrence")
            w.attributes["startTime"] = @all_day ? @start.strftime("%Y-%m-%d") : @start.xmlschema
            w.attributes["endTime"] = @all_day ? @end.strftime("%Y-%m-%d") : @end.xmlschema
            set_reminder(w)
          end
        end
      end        
      if not @attendees.empty?
        @attendees.each do |a|
          xml.root.add_element("gd:who", {"email" => a[:email], "valueString" => a[:name], "rel" => "http://schemas.google.com/g/2005#event.attendee"})
        end
      end
      xml.to_s
    end
    
    #Loads the event info from an XML string.
    def load(string)
      @xml = string
      @exists = true
      xml = REXML::Document.new(string)
      @etag = xml.root.attributes['etag']
      xml.root.elements.each(){}.map do |ele|
          case ele.name
             when 'updated'
                @updated = ele.text
             when 'published'
                @published = ele.text
             when 'edited'
                @edited = ele.text
             when 'id'
                @id, @edit_feed = ele.text
             when 'title'
                @title = ele.text
              when 'content'
                @content = ele.text
              when "when"
                @start = Time.parse(ele.attributes['startTime'])
                @end = Time.parse(ele.attributes['endTime'])
                ele.elements.each("gd:reminder") do |r|
                  @reminder = {:minutes => r.attributes['minutes'] ? r.attributes['minutes'] : 0, :hours => r.attributes['hours'] ? r.attributes['hours'] : 0, :days => r.attributes['days'] ? r.attributes['days'] : 0, :method => r.attributes['method'] ? r.attributes['method'] : ''}
                end
              when "where"
                @where = ele.attributes['valueString']
              when "link"
                if ele.attributes['rel'] == 'edit'
                  @edit_feed = ele.attributes['href']
                end
              when "who"
                if ele.attributes['rel'] == "http://schemas.google.com/g/2005#event.attendee"
                n = {}
                ele.attributes.each do |name, value|
                    case name
                      when "email"
                        n[:email] = value
                      when "valueString"
                        n[:name] = value
                    end
                  end                
               @attendees << n
               end
              when "eventStatus"
              case ele.attributes["value"] 
                when "http://schemas.google.com/g/2005#event.confirmed"
                 @status =  :confirmed
                when "http://schemas.google.com/g/2005#event.tentative"
                  @status = :tentative
                when "http://schemas.google.com/g/2005#event.cancelled"
                  @status = :cancelled
              end
            when 'recurrence'
              @recurrence = Recurrence.new(ele.text)
            when "transparency"
               case ele.attributes["value"]
                  when "http://schemas.google.com/g/2005#event.transparent" 
                    @transparency = :free
                  when "http://schemas.google.com/g/2005#event.opaque"
                    @transparency = :busy
                end
            end      
        end
    end
    
    #Reloads the event data from the Google Calendar Service.  Returns true if successful,
    #false otherwise.
    def reload
      t = Event.find(@calendar, @id)
      if t
        if load(t.to_xml)
         return true
        else
         return false
        end
      else
        return false
      end
    end
    
    #Finds the event that matches a query term in the event title or description.
    #  
    #'query' is a string to perform the search on or an event id.
    # 
    #The params hash can contain the following hash values
    #* *scope*: may be :all or :first, indicating whether to return the first record found or an array of all records that match the query.  Default is :all.
    #* *range*: a hash including a :start and :end time to constrain the search by
    #* *max_results*: an integer indicating the number of results to return.  Default is 25.
    #* *sort_order*: either 'ascending' or 'descending'.
    #* *single_events*: either 'true' to return all recurring events as a single entry, or 'false' to return all recurring events as a unique event for each recurrence.
    #* *ctz*: the timezone to return the event times in
    def self.find(calendar, query = '', params = {})
      query_string = ''
      
      begin 
        test = URI.parse(query).scheme
      rescue Exception => e
        test = nil
      end
      
      if test
        puts "id passed, finding event by id" if calendar.service.debug
        puts "id = "+query if calendar.service.debug
        event_id = query.gsub("/events/","/private/full/") #fix provided by groesser3
      
        es = calendar.service.send_get(event_id)
        puts es.inspect if calendar.service.debug
        if es
          entry = REXML::Document.new(es.read_body).root
          puts 'event found' if calendar.service.debug
          Event.define_xml_namespaces(entry)
          event = Event.new(calendar)
          event.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
          return event
        end
        return nil
      end

  
      #parse params hash for values
      range = params[:range] || nil
      max_results = params[:max_results] || nil
      sort_order = params[:sortorder] || nil
      single_events = params[:singleevents] || nil
      timezone = params[:ctz] || nil
      
      #set up query string
      query_string += "q=#{CGI.escape(query)}" if query
      if range
        if not range.is_a? Hash or (range.size > 0 and (not range[:start].is_a? Time or not range[:end].is_a? Time))
          raise "The date range must be a hash including the :start and :end date values as Times"
        else
          date_range = ''
          if range.size > 0
            #Added via patch from Fabio Inguaggiato
            query_string += "&start-min=#{CGI::escape(range[:start].xmlschema)}&start-max=#{CGI::escape(range[:end].xmlschema)}"
          end
        end
      end
      query_string += "&max-results=#{max_results}" if max_results
      query_string += "&sortorder=#{sort_order}" if sort_order
      query_string += "&ctz=#{timezone.gsub(" ", "_")}" if timezone
      query_string += "&singleevents=#{single_events}" if single_events
      if query_string
        events = calendar.service.send_get("http://www.google.com/calendar/feeds/#{calendar.id}/private/full?"+query_string)
        ret = []
        REXML::Document.new(events.read_body).root.elements.each("entry"){}.map do |entry|
          Event.define_xml_namespaces(entry)
          event = Event.new(calendar)
          event.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
          ret << event
        end
      end
      if params[:scope] == :first
        return ret[0]
      else
        return ret
      end
    end
    
    #Returns true if the event exists on the Google Calendar Service.
    def exists?
      return @exists
    end
  
    private 
    @exists = false
    @calendar = nil
    @xml = nil
    @etag = nil
    @recurrence = nil
    @deleted = false
    @edit_feed = ''
    
    def self.define_xml_namespaces(entry)
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns:app"] = "http://www.w3.org/2007/app"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      entry.attributes["xmlns:georss"] = "http://www.georss.org/georss"
      entry.attributes["xmlns:gml"] = "http://www.opengis.net/gml"
    end
    
    def set_reminder(ele)
      ele.delete_element("gd:reminder")
      if @reminder
        e = ele.add_element("gd:reminder")
        used = false
        if @reminder[:minutes] 
          e.attributes['minutes'] = @reminder[:minutes] 
          used = true
        elsif @reminder[:hours] and not used
          e.attributes['hours'] = @reminder[:hours]
          used = true
        elsif @reminder[:days] and not used
          e.attributes['days'] = @reminder[:days]
        end
        if @reminder[:method] 
          e.attributes['method'] = @reminder[:method]
        else
          e.attributes['method'] = 'email'
        end
      else
        ele.delete_element("gd:reminder")
      end
    end
  end
end

