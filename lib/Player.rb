require_relative "Entity"

class Player < Entity
  attr_reader :old_msgs
  def initialize(game, rng, templates, template)
    super(game, rng, templates, template)
    @old_msgs = []
    @last_target = self
  end
  
  def see?(l, x, y)
    return !!@fov[[l,x,y]]
  end
  
  def look(game)
    @fov = game.do_field_of_view(self, 20)
  end
  
  def show_tile(game, god, l, x, y)
    if @fov[[l, x, y]] || god
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
  
  def more_messages?
    @pending_messages.size
  end
  
  def last_msg
    if @pending_messages[0].nil?
      ""
    else 
      @old_msgs << @pending_messages.shift
      @old_msgs[-1][1]
    end
  end
end