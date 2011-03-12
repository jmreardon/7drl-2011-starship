require "ncursesw"

class Display
  STATUS_WIDTH = 30
  MSG_HEIGHT = 2
  include Ncurses
  attr_accessor :window
  
  def initialize(colours)
    @colours = colours
  end
    
  def show(game)
    beginning_time = Time.now
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
      if gy < 0 || gy > game.level_width
        next
      end
      (0..map_width).zip(map_x..(map_x+map_width)).each do |sx,gx|
        tile, colour = player.show_tile(game, player_loc[0], gx, gy)
        if(@colours)
          fail tile unless colour
          @window.color_set(colour, nil)
        end
        if tile != ' '
          blank_row = false
        end
        @window.mvaddstr(sy,sx, tile)
      end
    end
    
    if(@colours)
      @window.color_set(0, nil)
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
    room = game.room_for(*player_loc)
    @window.mvaddstr(1, side_start, "Room #{room[:number]} - #{room[:name]}") if room
    @window.mvaddstr(2, side_start, "Objects #{game.object_count}")
    end_time = Time.now
    @window.mvaddstr(3, side_start, "Time #{((end_time - beginning_time)*1000).round} milliseconds")
   
  ensure
    Ncurses.refresh
  end
  
end