require "yaml"

load "lib/MapBuilder.rb"
load "lib/Entity.rb"
load "lib/Player.rb"

class GameState
  attr_writer :config
  def initialize(rng, config)
    @rng = rng
    @config = config
    data = MapBuilder.new.constructMap(rng)
    @mapData = data[:map]
    @levelWidth = data[:width]
    @rooms = data[:rooms]
    @player = Player.new(:symbol => '@', :name => "You", :mobile => true, :description => "The player")
    @objects = Hash.new
    @objects.compare_by_identity
    @objects[@player] = [0, find_floor(), @levelWidth/2]
    @locObjects = Hash.new
    @objects.each do |k,v|
      if @locObjects[v].nil?
        @locObjects[v] = Hash.new
      end
      @locObjects[v][k] = true
    end
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
    else 
      mob << "I don't know about action #{action}"
    end
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
    {:levels => 8, :length => @mapData[0][@levelWidth/2].length, :width => @mapData[0].length}
  end
  
  def player
    return @player
  end
  
  #stored in l,x,y
  def player_loc
    return @objects[@player]
  end
  
  def symbol_at(*loc)
    objs = objects_at loc
    if !objs.nil? and objs.size > 0
      objs.first.first.symbol
    else
      @config[:mapSymbols][tile_at(loc)]
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
end