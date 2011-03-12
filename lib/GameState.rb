require "yaml"

load "lib/MapBuilder.rb"
load "lib/Entity.rb"
load "lib/Player.rb"
load "lib/PermissiveFieldOfView.rb"

class GameState
  include PermissiveFieldOfView
  
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  attr_writer :config
  attr_reader :rooms, :level_width
  def initialize(rng, config)
    @rng = rng
    @config = config
    data = MapBuilder.new.constructMap(rng, @config[:room_templates], @config[:objects])
    @mapData = data[:map]
    @level_width = data[:width]
    @height = data[:width]
    @width = data[:length]
    @rooms = data[:rooms]
    @player_seen = Hash.new(false)
    @player = Player.new(:symbol => ['@', 1], :name => "You", :kind => :player, :mobile => true, :description => "The player")
    @objects = Hash.new
    @objects.compare_by_identity
    @objects[@player] = [0, find_floor(), @level_width/2]
    data[:objects].each do |obj, loc|
      @objects[obj] = loc
    end
    @locObjects = Hash.new
    @objects.each do |k,v|
      if @locObjects[v].nil?
        @locObjects[v] = Hash.new
      end
      @locObjects[v][k] = true
    end
  end
  
  def object_count 
    @objects.size
  end
  
  def room_for(l, x, y)
    room = @rooms[l].find{|k,v| k[0]<=x && k[1]<=y && k[2] >=x && k[3] >= y}
    if room
      room[1]
    else 
      nil
    end
  end
  
  def player_seen?(l, x, y)
    return @player_seen[[l,x,y]]
  end
  
  def do_field_of_view(mob, range)
    @fov_level = @objects[mob][0]
    @fov_visible = Hash.new(false)
    @fov_player = mob == @player
    mob_loc = @objects[mob]
    do_fov(mob_loc[1], mob_loc[2], range)
    return @fov_visible
  end
  
  def light(x, y)
    @fov_visible[[@fov_level, x, y]] = true
    if @fov_player
      @player_seen[[@fov_level,x,y]] = tile_at(@fov_level,x,y)
    end
  end
  
  def blocked?(x, y)
    !@config[:untraversable][tile_at(@fov_level, x, y)].nil?
  end
  
  def act(mob, action, opts = {})
    case action
    when :cmd_up
      move mob, 0, 0, -1
    when :cmd_down
      move mob, 0, 0, 1
    when :cmd_left
      move mob, 0, -1, 0
    when :cmd_right
      move mob, 0, 1, 0
    when :cmd_up_left
      move mob, 0, -1, -1
    when :cmd_up_right
      move mob, 0, 1, -1
    when :cmd_down_left
      move mob, 0, -1, 1
    when :cmd_down_right
      move mob, 0, 1, 1
    when :cmd_lift_up
      move mob, 1, 0, 0
    when :cmd_lift_down
      move mob, -1, 0, 0
    when :cmd_open
      open mob
    when :cmd_close
      close mob
    else 
      mob << "I don't know about action #{action}"
    end
  end
  
  def traversable?(mob, curr, loc)
    if curr[0] != loc[0] 
      return "There is no lift here" if tile_at(curr) != :lift
      return "The lift does not go there" if tile_at(loc) != :lift
      return "Lift in use" if !objects_at(loc).empty?
    end
    return "Something is here" if !objects_at(loc).empty? 
    return @config[:untraversable][tile_at(loc)]
  end
  
  def map_dimensions
    {:levels => 8, :length => @mapData[0][@level_width/2].length, :width => @mapData[0].length}
  end
  
  def player
    return @player
  end
  
  #stored in l,x,y
  def player_loc
    return @objects[@player]
  end
  
  def symbol_for(thing)
    @config[:mapSymbols][thing] || [nil, 0]
  end
  
  def symbol_at(*loc)
    objs = objects_at loc
    if !objs.nil? and objs.size > 0
      objs.first.first.symbol || [nil, 0]
    else
      @config[:mapSymbols][tile_at(loc)] || [nil, 0]
    end
  end
  
  def objects_at(*loc)
    if(loc.size == 1)
      l = loc[0][0]
      x = loc[0][1]
      y = loc[0][2]
    else 
      l = loc[0]
      x = loc[1]
      y = loc[2]
    end
    return @locObjects[[l,x,y]] || {}
  end
  
  def tile_at(*loc)
    if(loc.size == 1)
      l = loc[0][0]
      x = loc[0][1]
      y = loc[0][2]
    else 
      l = loc[0]
      x = loc[1]
      y = loc[2]
    end
    val = if l < 0 or x < 0 or y < 0 or @mapData[l].nil? or @mapData[l][y].nil? or @mapData[l][y][x].nil?
        nil 
      else 
        @mapData[l][y][x] 
      end
    if val.nil? 
      :blank 
    else 
      val 
    end
  end
  
  private
  
  def offset(loc, l, x, y)
    return [loc[0]+l,loc[1]+x,loc[2]+y]
  end
  
  def open_close(mob, to_use, nothing_msg, changed_door, changed_hatch)
    mob_loc = @objects[mob]
    targets = AROUND.map{|l,x,y| offset(mob_loc,l,x,y)}.select{|loc| to_use.include?(tile_at(loc))}
    if targets.size == 0
      mob << nothing_msg
    elsif targets.size > 1
      mob << "There are more doors here than the programmer anticipated, not sure which to use"
    else
      loc = targets.first
      @mapData[loc[0]][loc[2]][loc[1]] = if tile_at(loc) == to_use.first then changed_door else changed_hatch end
    end
  end
  
  # for initial player placement
  def find_floor()
    floor = 0
    for x in 0..map_dimensions[:length]
      floor = x
      break if tile_at(0, x, map_dimensions[:width]/2) == :floor
    end
    return floor
  end
  
  
  #mob action definitions
  
  def close(mob)
    open_close(mob, [:door_open, :hatch_open], "There is nothing to close here", :door, :hatch)
  end
  
  def open(mob)
    open_close(mob, [:door, :hatch], "There is nothing to open here", :door_open, :hatch_open)
  end
  
  def move(mob, l, x, y)
    unless mob.mobile
      mob << "You are not mobile, you cannot move"
      return false
    end
    
    mob_loc = @objects[mob]
    next_loc = offset mob_loc, l, x, y
    
    traversable_msg = traversable?(mob, mob_loc, next_loc)
    unless traversable_msg.nil?
      mob << traversable_msg
      return false
    end
    
    @locObjects[mob_loc].delete(mob)
    @locObjects[next_loc] = Hash.new if @locObjects[next_loc].nil?
    @locObjects[next_loc][mob] = true
    @objects[mob] = next_loc
  end
  
end