# Hackathon Scheduling Tool

require "csv"
require "time"

# Control class for adding, deleting, and modifying rooms and events, as well as generating the schedule
class Control
    def initialize
        # Initialize hashmaps to store rooms/events and section variables
        @rooms = {} # Hashmap for buildings of rooms
        @events = {}  # Hashmap for dates of events
        @openingRoom = nil
        @mealRooms = []
        @workRooms = []
        @closingRoom = nil
    end

    # Sets the constraints for generating the plan
    def setConstraints(date, time, duration, attendees)
        # Sets the date, time, duration, and attendees
        @date = date
        @time = time
        @duration = duration
        @attendees = attendees
    end

    # Function to validate time input (yyyy-mm-dd)
    def validDate(date)
        # Tests if the date format is correct
        begin
            Date.strptime(date, '%Y-%m-%d')
            true
        rescue ArgumentError
            false
        end
    end
    
    # Function to validate time input (hh:mm AM/PM)
    def validTime(time)
        # Tests if the time format is correct
        begin
            Time.strptime(time, '%I:%M %p')  # Ensures the time is in AM/PM format
            true
        rescue ArgumentError
            false
        end
    end
    
    # Function to validate duration input (hh:mm)
    def validDuration(duration)
        # Tests if the duration format is correct
        begin
            Time.strptime(duration, '%H:%M')  # Validates the 24-hour format (hh:mm)
            true
        rescue ArgumentError
            false
        end
    end
    
    # Adds a room to the rooms hashmap
    def addRoom(building, room, capacity, computers_available, seating_available, seating_type, food_allowed, priority, room_type)
        # Checks if room and capacity are positive integers and adds the room to the rooms hashmap
        if room.to_i > 0 && capacity.to_i > 0
            room = Room.new(building: building, room: room, capacity: capacity, computers_available: computers_available, seating_available: seating_available, seating_type: seating_type, food_allowed: food_allowed, priority: priority, room_type: room_type)
            @rooms[building] ||= [] # Initializes the building key if it's new
            @rooms[building] << room # Adds room value to the building's key
        end
    end

    # Adds an event to the event hashmap
    def addEvent(building, room, date, time, duration, booking_type)
        # Checks event if room and capacity are positive integers and adds the event to the events hashmap
        if room.to_i > 0
            event = Event.new(building: building, room: room, date: date, time: time, duration: duration, booking_type: booking_type)
            @events[date] ||= [] # Initializes the date key if it's new
            @events[date] << event # Adds event value to the date's key
        end
    end
    
    # Deletes an event from the event hashmap
    def delEvent(building, room, date, time)
        # Deletes an event from the event array if the event is found
        if @events[date]
            detectedEvent = @events[date].find { |event|
                event.building == building && event.room == room && event.time == time
            }
            if detectedEvent
                @events[date].delete(detectedEvent)
            end
            @events.delete(date) if @events[date].empty?
        end
    end
    
    # Updates an event from the event hashmap
    def updateEvent(building, room, date, time, newBuilding, newRoom, newDate, newTime, newDuration, newBooking_type)
        # Updates the event details and moves it to a new date if necessary
        if @events[date]
            detectedEvent = @events[date].find { |event|
                event.building == building && event.room == room && event.time == time
            }
            if detectedEvent # Updates event attributes
                detectedEvent.building = newBuilding
                detectedEvent.room = newRoom
                detectedEvent.date = newDate
                detectedEvent.time = newTime
                detectedEvent.duration = newDuration
                detectedEvent.booking_type = newBooking_type    
                if newDate != date # Changes the event's date key if the date changes
                    @events[date].delete(detectedEvent)
                    @events.delete(date) if @events[date].empty?    
                    @events[newDate] ||= []
                    @events[newDate] << detectedEvent
                end
            end
        end
    end
    
    # Plan generation using the constraints set by the user
    def generatePlan()
        # Converts the time and duration constraints to float values
        timeTracker = Time.parse(@time).hour + (Time.parse(@time).min * (1.0/60)) # keeps track of time
        timeDuration = Time.parse(@duration).hour + (Time.parse(@duration).min * (1.0/60))
        duration = 1
        timeEnd = timeTracker + timeDuration
        timeEndParsed = Time.parse(@time) + (timeDuration * 3600)
        section = 0
        searching = true
        
        # Searches each room by building with the highest count of rooms
        while searching
            sectionCheck = false
            capacityCt = 0 # Counts section capacity for work and meal sections 
            compCheck = false # Flag to check if a room with a computer with >= 10% of attendee capacity has been added to that time and section
            mealRoomCheck = 0 # checks to see if there's >= 2 meal rooms
            @rooms.each do |building, rooms|
                rooms.each do |room|
                    next if section < 3 && room == @openingRoom
                    sectionCheck = false
                    # Check if the room has any event collisions and meets basic section requirements
                    if !(eventCheck(timeTracker, duration, room)) && ((room.capacity.to_i >= @attendees.to_i && room.room_type != "Computer Lab" && (section == 0 || section == 3)) || (section == 1 || (section == 2 && room.room_type != "Computer Lab")))
                        compCheck = (section == 1 && (room.capacity.to_i * 10) >= @attendees.to_i && room.room_type == "Computer Lab")
                        capacityCt += room.capacity.to_i if section != 1
                        # Organizes rooms by section
                        if section == 0
                            # Figures out the best openingRoom
                            @openingRoom = room
                            timeTracker = timeTracker + 1
                            section = section + 1
                            duration = (timeTracker + 6 > timeEnd - 3) ? timeEnd - timeTracker - 3 : 6
                            sectionCheck = true
                            break
                        elsif section == 1
                            # Figures out the best work rooms for that time, tracked by timeTracker and duration
                            @workRooms << room if (capacityCt + room.capacity.to_i * (10/9) < @attendees.to_i && room.room_type != "Computer Lab") || compCheck
                            capacityCt += room.capacity.to_i
                            if capacityCt >= @attendees.to_i && compCheck
                                section += (timeTracker + 6 >= timeEnd - 3) ? 2 : 1
                                timeTracker += (timeTracker + 6 > timeEnd - 3) ? timeEnd - timeTracker - 3 : 6
                                if (timeTracker + 6 >= timeEnd - 3)
                                    duration = 3
                                else
                                    duration = 1
                                end
                                sectionCheck = true
                                @workRooms << nil
                            end
                            break if sectionCheck
                        elsif section == 2
                            # Figures out the best meal rooms for that time
                            mealRoomCheck += 1
                            @mealRooms << room
                            if capacityCt >= @attendees.to_i && mealRoomCheck >= 2
                                section += (timeTracker + 1 != timeEnd - 3) ? -1 : 1
                                timeTracker += 1
                                if (timeTracker + 1 != timeEnd - 3)
                                    duration = (timeTracker + 6 > timeEnd - 3) ? timeEnd - timeTracker - 3 : 6
                                else
                                    duration = 3
                                end
                                sectionCheck = true
                                @mealRooms << nil
                            end
                            break if sectionCheck
                        elsif section == 3
                            # Figures out the best closing room
                            # If there's no event collisions, it will pick the same room as the opening room, using the correct time and duration
                            @closingRoom = room
                            if !(eventCheck(timeTracker, duration, @openingRoom))
                                @closingRoom = @openingRoom
                            end
                            timeTracker += 3
                            section += 1
                            duration = 3
                            searching = false
                            sectionCheck = true
                            break
                        end
                    end
                end
                break if sectionCheck
            end
        end

        # Information for putting all the rooms into the CSV file
        print "Please enter the name for the CSV file (without extension): "
        fileName = gets.chomp
        fileName += ".csv"

        # Opens the CSV file with the name the user entered
        csvCreate(fileName, timeEndParsed)
    end
    
    # Checks for overlapping events using the current room and all events within the date constraint
    def eventCheck(timeTracker, duration, room)
        if @events[@date] && @events[@date]&.any?
            @events[@date].each do |event|
                if event.room == room.room && event.building == room.building
                    # If there's an event in the same room on that day, eventOverlapCheck checks if there's a time conflict
                    return true if eventOverlapCheck(timeTracker, duration, event.time, event.duration)
                end
            end
        end
        return false
    end

    # Checks if the current room and matching room's found event have overlapping times
    def eventOverlapCheck(thisStart, thisDuration, eventTime, eventDuration)
        thisEnd = thisStart + thisDuration
        overlapStart = Time.parse(eventTime).hour + (Time.parse(eventTime).min * (1.0/60))
        overlapEnd = overlapStart + Time.parse(eventDuration).hour + (Time.parse(eventDuration).min * (1.0/60))
        return true if (thisEnd > overlapStart && thisStart < overlapEnd)
        return false
    end
    
    # Creates the output CSV file with the generated plan
    def csvCreate(fileName, timeEnd)
        # Goes through each section and iterates through the selected rooms, organizing them by time, adding them to the CSV file
        csvTime = Time.parse(@time)
        workRoomsProgress = 0
        workRoomsSize = @workRooms.size
        mealRoomsProgress = 0
        mealRoomsSize = @mealRooms.size

        # Creates the new CSV file with the user-specified name
        CSV.open(fileName, "wb", quote_char: '"', force_quotes: false) do |csv|
            csv << ["--- Generated Schedule ---"]
            csv << ["Building", "Room", "Capacity", "Computers Available", "Seating Available", "Seating Type", "Food Allowed", "Priority", "Room Type"]
            csv << []
            # Adds the selected opening room
            csv << ["Opening Room - #{csvTime.strftime('%I:%M %p')} to #{(csvTime + 3600).strftime('%I:%M %p')}"]
            csv << [@openingRoom.building, @openingRoom.room, @openingRoom.capacity, @openingRoom.computers_available, @openingRoom.seating_available, @openingRoom.seating_type, @openingRoom.food_allowed, @openingRoom.priority, @openingRoom.room_type]
            csvTime += 3600

            while workRoomsProgress < workRoomsSize
                csv << []
                hypotheticalTime = csvTime + ((csvTime + (6 * 3600) > timeEnd - (3 * 3600)) ? timeEnd - csvTime - (3 * 3600) : (6 * 3600))
                # Adds the work rooms to the file
                csv << ["Work Rooms - #{csvTime.strftime('%I:%M %p')} to #{hypotheticalTime.strftime('%I:%M %p')}"]
                while @workRooms[workRoomsProgress] != nil
                    csv << [@workRooms[workRoomsProgress].building, @workRooms[workRoomsProgress].room, @workRooms[workRoomsProgress].capacity, @workRooms[workRoomsProgress].computers_available, @workRooms[workRoomsProgress].seating_available, @workRooms[workRoomsProgress].seating_type, @workRooms[workRoomsProgress].food_allowed, @workRooms[workRoomsProgress].priority, @workRooms[workRoomsProgress].room_type]
                    workRoomsProgress += 1
                end
                workRoomsProgress += 1
                csvTime += (csvTime + (6 * 3600) > timeEnd - (3 * 3600)) ? timeEnd - csvTime - (3 * 3600) : (6 * 3600)
                if mealRoomsProgress < mealRoomsSize
                    csv << []
                    # Adds the meal rooms to the file
                    csv << ["Meal Rooms - #{csvTime.strftime('%I:%M %p')} to #{(csvTime + 3600).strftime('%I:%M %p')}"]
                    while @mealRooms[mealRoomsProgress] != nil
                        csv << [@mealRooms[mealRoomsProgress].building, @mealRooms[mealRoomsProgress].room, @mealRooms[mealRoomsProgress].capacity, @mealRooms[mealRoomsProgress].computers_available, @mealRooms[mealRoomsProgress].seating_available, @mealRooms[mealRoomsProgress].seating_type, @mealRooms[mealRoomsProgress].food_allowed, @mealRooms[mealRoomsProgress].priority, @mealRooms[mealRoomsProgress].room_type]
                        mealRoomsProgress += 1
                    end
                    csvTime += 3600
                    mealRoomsProgress += 1
                end
            end
            
            # Adds the closing room to the file
            csv << []
            csv << ["Closing Room - #{csvTime.strftime('%I:%M %p')} to #{(csvTime + (3 * 3600)).strftime('%I:%M %p')}"]
            csv << [@closingRoom.building, @closingRoom.room, @closingRoom.capacity, @closingRoom.computers_available, @closingRoom.seating_available, @closingRoom.seating_type, @closingRoom.food_allowed, @closingRoom.priority, @closingRoom.room_type]
        end
        # Prints a message saying that the CSV file has been successfully generated
        puts "Your schedule plan has been generated! Check \"#{fileName}\" in this directory to see the schedule."
    end

    # Displays a list of every room according to their building
    def listRooms
        @rooms.each do |key, value|
            puts "Key: #{key}"
            value.each do |value|
                puts "  Value: #{value}"
            end
            puts "\n"
        end
    end

    # Displays a list of every event according to their date
    def listEvents
        @events.each do |key, value|
            puts "Key: #{key}"
            value.each do |value|
                puts "  Value: #{value}"
            end
            puts "\n"
        end
    end
end

# Room class for every room in the rooms_list.csv file
class Room
    attr_accessor :building, :room, :capacity, :computers_available, :seating_available, :seating_type, :food_allowed, :priority, :room_type

    # Initializes the Room object with its corresponding attributes
    def initialize(building:, room:, capacity:, computers_available:, seating_available:, seating_type:, food_allowed:, priority:, room_type:)
        @building = building
        @room = room
        @capacity = capacity
        @computers_available = computers_available
        @seating_available = seating_available
        @seating_type = seating_type
        @food_allowed = food_allowed
        @priority = priority
        @room_type = room_type
    end
  
    def to_s
        # Converts each room into a CSV format for easier debugging
        "#{@building},#{@room},#{@capacity},#{@computers_available},#{@seating_available},#{@seating_type},#{@food_allowed},#{@priority},#{@room_type}"
    end
end

# Event class for every event in the reserved_rooms.csv file
class Event
    attr_accessor :building, :room, :date, :time, :duration, :booking_type

    # Initializes the Event object with its corresponding attributes
    def initialize(building:, room:, date:, time:, duration:, booking_type:)
        @building = building
        @room = room
        @date = date
        @time = time
        @duration = duration
        @booking_type = booking_type
    end
  
    def to_s
        # Converts each event into a CSV format for easier debugging
        "#{@building},#{@room},#{@date},#{@time},#{@duration},#{@booking_type}"
    end
end

# Creates a new Control object
control = Control.new

# Reads from the rooms_list.csv file to add values to the @rooms hashmap
CSV.foreach('rooms_list.csv', headers: true, converters: ->(field) { field.to_s }) do |row|
    building = row['Building']
    room = row['Room']
    capacity = row['Capacity']
    computers_available = row['Computers Available']
    seating_available = row['Seating Available']
    seating_type = row['Seating Type']
    food_allowed = row['Food Allowed']
    priority = row['Priority']
    room_type = row['Room Type']
    control.addRoom(building, room, capacity, computers_available, seating_available, seating_type, food_allowed, priority, room_type)
end

# Reads from the reserved_rooms.csv file to add values to the @events hashmap
CSV.foreach('reserved_rooms.csv', headers: true, converters: ->(field) { field.to_s }) do |row|
    building = row['Building']
    room = row['Room']
    date = row['Date']
    time = row['Time']
    duration = row['Duration']
    booking_type = row['Booking Type']
    control.addEvent(building, room, date, time, duration, booking_type)
end

# Placeholder values for the user-specified constraints
date = ""
time = ""
duration = ""
attendees = ""

# Asks user to enter a valid date, if the format's incorrect the program will ask again
loop do
    print "Enter the date of the event (yyyy-mm-dd): "
    date = gets.chomp
    if control.validDate(date)
        break
    else
        puts "Invalid date, use the format <yyyy-mm-dd>"
    end
end

# Asks user to enter a valid time, if the format's incorrect the program will ask again
loop do
    print "Enter the start time of the event (hh:mm AM/PM): "
    time = gets.chomp
    if control.validTime(time)
        break
    else
        puts "Invalid time, use the format <hh:mm AM/PM>"
    end
end

# Asks user to enter a valid duration, if the format's incorrect the program will ask again
loop do
    print "Enter the duration of the event (hh:mm): "
    duration = gets.chomp
    if control.validDuration(duration)
        break
    else
        puts "Invalid duration, use the format <hh:mm>"
    end
end

# Asks user to enter a valid number of attendees, if the format's incorrect the program will ask again
loop do
    print "Enter the number of attendees: "
    attendees = gets.chomp
    if attendees.to_i.to_s == attendees && attendees.to_i > 0
        break
    else
        puts "Invalid number of attendees, use a positive integer"
    end
end  

# Converts the constraints to strings for easier conversions when generating the plan
date = date.to_s
time = time.to_s
duration = duration.to_s.sub(/^0/, '')
attendees = attendees.to_s

# Sets the constraints and generates the plan for it
control.setConstraints(date, time, duration, attendees)
puts "Generating plan for #{date} at #{time}, with a duration of #{duration} hours with #{attendees} attendees."
control.generatePlan()
