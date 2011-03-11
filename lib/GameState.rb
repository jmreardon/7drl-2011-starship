require "yaml"

load "lib/MapBuilder.rb"
load "lib/Entity.rb"

class GameState
  def initialize(rng)
    @rng = rng
    data = MapBuilder.new.constructMap(rng)
    @mapData = data[:map]
    @levelWidth = data[:width]
    @rooms = data[:rooms]
    @player = Entity.new(:symbol => '@', :name => "You", :description => "The player")
    @objects = Hash.new
    @objects.compare_by_identity
    @objects[@player] = [0, find_floor(), @levelWidth/2]
    @locObjects = @objects.invert
  end
  
  def map_dimensions
    {:levels => 8, :length => @mapData[0][@levelWidth/2].length, :width => @mapData[0].length}
  end
  
  def player
    return @player
  end
  
  def player_loc
    return @objects[@player]
  end
  
  def objects_at(*loc)
    l = loc[0]
    x = loc[1]
    y = loc[2]
    return @locObjects[[l,x,y]]
  end
  
  def tile_at(*loc)
    l = loc[0]
    x = loc[1]
    y = loc[2]
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