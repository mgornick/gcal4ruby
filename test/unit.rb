#!/usr/bin/ruby

require 'rubygems'
require 'gcal4ruby'
include GCal4Ruby

@service = Service.new
@username = nil
@password = nil

def tester
  if ARGV.include?("-d")
      @service.debug = true
  end
  ARGV.each do |ar|
    if ar.match("username=")
      @username = ar.gsub("username=", "")
    end
    if ar.match("password=")
      @password = ar.gsub("password=", "")
    end
  end
  service_test
  calendar_test
  event_test
  event_recurrence_test
end

def service_test
  puts "---Starting Service Test---"
  puts "1. Authenticate"
  if @service.authenticate(@username, @password)
    successful
  else
    failed
  end
  
  puts "2. Calendar List"
  cals = @service.calendars
  if cals
    successful "Calendars for this Account:"
    cals.each do |cal|
      puts cal.title
    end
  else
    failed
  end
end

def calendar_test
  puts "---Starting Calendar Test---"
  
  puts "1. Create Calendar"
  cal = Calendar.new(@service)
  cal.title = "test calendar"+Time.now.to_s
  puts "Calender exists = "+cal.exists?.to_s
  if cal.save
    successful cal.to_xml
  else
    failed
  end
  
  puts "2. Edit Calendar"
  cal.title = "renamed title"
  if cal.save
    successful cal.to_xml
  else
    puts "Test 2 Failed"
  end
  
  puts "3. Find Calendar by ID"
  c = Calendar.find(@service, cal.id)
  if c.title == cal.title
    successful
  else
    failed "#{c.title} not equal to #{cal.title}"
  end
  
  puts "4. Delete Calendar"
  if cal.delete and not cal.title
    successful
  else
    failed
  end
end

def event_test
  puts "---Starting Event Test---"
  
  puts "1. Create Event"
  event = Event.new(@service.calendars[0])
  event.title = "Test Event"
  event.content = "Test event content"
  event.start = Time.now+1800
  event.end = Time.now+5400
  if event.save
    successful event.to_xml
  else
    failed
  end
  
  puts "2. Edit Event"
  event.title = "Edited title"
  if event.save
    successful event.to_xml
  else
    failed
  end
  
  puts "3. Reload Event"
  if event.reload
    successful
  end
  
  puts "4. Find Event by id"
  e = Event.find(@service.calendars[0], event.id)
  if e.title == event.title
    successful
  else
    failed "Found event doesn't match existing event"
  end
  
  puts "5. Delete Event"
  if event.delete
    successful 
  else
    failed
  end
end

def event_recurrence_test
  puts "---Starting Event Recurrence Test---"
  
  @first_start = Time.now
  @first_end = Time.now+3600
  @first_freq = {'weekly' => ['TU']}
  @second_start = Time.now+86000
  @second_end = Time.now+89600
  @second_freq = {'weekly' => ['SA']}
  
  puts "1. Create Recurring Event"
  event = Event.new(@service.calendars[0])
  event.title = "Test Recurring Event"
  event.content = "Test event content"
  event.recurrence = Recurrence.new({:start => @first_start, :end => @first_end, :frequency => @first_freq})
  if event.save 
    successful event.to_xml
  else
    failed("recurrence = "+event.recurrence.to_s)
  end
  
  puts "2. Edit Recurrence"
  event.title = "Edited recurring title"
  event.recurrence = Recurrence.new({:start => @second_start, :end => @second_end, :frequency => @second_freq})
  if event.save 
    successful event.to_xml
  else
    failed
  end
  
  puts "3. Delete Event"
  if event.delete
    successful 
  else
    failed
  end
end

def failed(m = nil)
  puts "Test Failed"
  puts m if m
  exit()
end

def successful(m = nil)
  puts "Test Successful"
  puts m if m
end

tester