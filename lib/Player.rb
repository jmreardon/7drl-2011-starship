load "lib/Entity.rb"

class Player < Entity
  attr_reader :old_msgs
  def initialize(template)
    super(template)
    @old_msgs = []
  end
  
  def look(game)
    @fov = game.do_field_of_view(self, 20)
  end
  
  def show_tile(game, l, x, y)
    if @fov[[l, x, y]]
      return game.symbol_at(l,x,y) 
    else 
      tile = game.player_seen?(l, x, y) 
      if tile 
        if tile == :floor
          tile = :blank
        end
        game.symbol_for(tile)
      else
        [' ', 0] 
      end
    end
  end
  
  def last_msg
    if @pending_messages[-1].nil?
      ""
    else 
      @old_msgs << @pending_messages.pop
      @old_msgs[-1][1]
    end
  end
end