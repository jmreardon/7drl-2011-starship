require "yaml"

load "lib/MapBuilder.rb"
load "lib/Entity.rb"
load "lib/Player.rb"
load "lib/EnemyAI.rb"
load "lib/PermissiveFieldOfView.rb"

class GameState
  include PermissiveFieldOfView
  
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  attr_writer :config
  attr_reader :rooms, :level_width
  def initialize(rng, config)
    @rng = rng
    @config = config
    @ai = EnemyAI.new(@rng)
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
      if opts[:dir] then open mob, opts[:dir] else :direction end
    when :cmd_close
      if opts[:dir] then close mob, opts[:dir] else :direction end
    when :cmd_activate
      if opts[:dir] then activate mob, opts[:dir] else :direction end
    when :cmd_login
      login mob, opts[:who]
    else 
      mob << "I don't know about action #{action}"
    end
  end
  
  def cmd_to_direction(cmd)
    case cmd
    when :cmd_up
      [0, 0, -1]
    when :cmd_down
      [0, 0, 1]
    when :cmd_left
      [0, -1, 0]
    when :cmd_right
      [0, 1, 0]
    when :cmd_up_left
      [0, -1, -1]
    when :cmd_up_right
      [0, 1, -1]
    when :cmd_down_left
      [0, -1, 1]
    when :cmd_down_right
      [0, 1, 1]
    else
      false
    end
  end
  
  def traversable?(mob, curr, loc)
    if curr[0] != loc[0] 
      return "There is no lift here" if tile_at(curr) != :lift
      return "The lift does not go there" if tile_at(loc) != :lift
      return "Lift in use" if !objects_at(loc).empty?
    end
    return "A #{objects_at(loc).first[0].name} is here" if !objects_at(loc).empty? 
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
  
  def close(mob, dir)
    open_close(mob, dir, [:door_open, :hatch_open], "There is nothing to close there", :door, :hatch)
  end
  
  def open(mob, dir)
    open_close(mob, dir, [:door, :hatch], "There is nothing to open there", :door_open, :hatch_open)
  end

  def open_close(mob, dir, to_use, nothing_msg, changed_door, changed_hatch)
    mob_loc = @objects[mob]
    loc = offset mob_loc, *dir
    if to_use.include?(tile_at(loc))
      @mapData[loc[0]][loc[2]][loc[1]] = if tile_at(loc) == to_use.first then changed_door else changed_hatch end
    else
      mob << nothing_msg
    end
  end
  
  def move(mob, l, x, y)
    unless mob.mobile
      mob << "You are not mobile, you cannot move"
      return false
    end
    
    mob_loc = @objects[mob]
    next_loc = offset mob_loc, l, x, y
    
    #check for interactions besides moving later
    
    
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

  def login(mob, controller)
    controller << "Attempting to log in..." << "Lockout in effect. This access has been reported to security.".upcase
    @ai << [:intruder, @objects[mob]]
  end
  
  def activate(mob, dir)
    mob_loc = @objects[mob]
    target_loc = offset mob_loc, *dir
  
    target = @locObjects[target_loc].find{ |x,t| x.action }
    if target
      act target[0], target[0].action, :who => mob
    else
      mob << "There is nothing to active there"
    end
  end
  
end