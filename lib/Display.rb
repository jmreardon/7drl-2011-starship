require "ncursesw"

class Display
  STATUS_WIDTH = 30
  MSG_HEIGHT = 2
  include Ncurses
  attr_accessor :window
    
  def show(game)
    lines   = []
    columns = []
    @window.getmaxyx(lines,columns)
    if lines[0] < 20 or columns[0] < 60
      @window.clear()
      @window.move(0,0)
      @window.addstr("Screen size too small")
      return
    end
    player = game.player
    
    map_width = columns[0] - STATUS_WIDTH
    map_height = lines[0] - MSG_HEIGHT
    player_loc = game.player_loc
    map_x = player_loc[1] - map_width/2
    map_y = player_loc[2] - map_height/2
    
    player.look game
    
    (0..map_height).zip(map_y..(map_y+map_height)).each do |sy,gy|
      (0..map_width).zip(map_x..(map_x+map_width)).each do |sx,gx|
        @window.mvaddstr(sy,sx, player.show_tile(game, player_loc[0], gx, gy))
      end
    end
    
    @window.move(map_height+1, 0)
    @window.clrtobot
    
    msg = player.last_msg
    unless msg.nil?
      @window.mvaddstr(map_height, 0, msg)
    end
    
    #clear sidebar
    (0..lines[0]).each do |sy|
      @window.move(sy, map_width+1)
      @window.clrtoeol
    end
    
    #display sidebar
    side_start = map_width+2
    @window.mvaddstr(0, side_start, "Deck #{player_loc[0]+1}")
    
  ensure
    Ncurses.refresh
  end
  
end