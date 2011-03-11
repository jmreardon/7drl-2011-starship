require "yaml"

load "lib/MapBuilder.rb"

class GameState
  def initialize(rng)
    @rng = rng
    @mapData = MapBuilder.new.constructMap(rng)
  end
  
  
  def tileAt(l,x,y)
    return nil if l < 0 or x < 0 or y < 0
    return mapData[l][y][x]
  end
end