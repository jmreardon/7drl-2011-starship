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
    if @fov[[game.player_loc[0], x, y]] then 
      game.symbol_at(game.player_loc[0],x,y) 
    elsif game.player_seen?(l, x, y) 
      tile = game.tile_at(l,x,y)
      actual = case tile
        when :door_open
          :door
        when :hatch_open
          :hatch
        when :floor
          :blank
        else tile
      end
      game.symbol_for(actual)
    else
      ' ' 
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