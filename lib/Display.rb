require "ncursesw"

class Display
  STATUS_WIDTH = 30
  MSG_HEIGHT = 2
  include Ncurses
  attr_accessor :window
  
  def initialize(colours)
    @colours = colours
  end
  
  def mark(loc)
    @mark = loc
  end

  def new_game
    lines   = []
    columns = []
    @window.getmaxyx(lines,columns)
    @window.clear()
    
    message = ["During surprise assault on Earth, rebels",
               "have managed to commandeer a prototype",
               "warship. Just before they escaped to warp",
               "you were beamed aboard with simple orders:",
               "",
               "Take this vessel out of enemy hands by any means"]
  
    line = (lines[0] - message.length)/2 - 1
  
  
    max_width = message.max{|a,b| a.length <=> b.length }.length
    startx = (columns[0] - max_width)/2
    @window.mvaddstr(line-2, startx, "Storming the Ship")
    message.each do |m|
      @window.mvaddstr(line, startx, m)
      line+=1
    end  
      @window.mvaddstr(line+4, startx, "Press any key to continue")
    @window.getch
    @window.clear()
  end
  
  def game_over(message, player_health)
    lines   = []
    columns = []
    @window.getmaxyx(lines,columns)
      @window.clear()
    
    line = (lines[0] - message.length)/2 - 1
    
    
    max_width = message.max{|a,b| a.length <=> b.length }.length
    startx = (columns[0] - max_width)/2
    @window.mvaddstr(line-2, startx, "Game Over")
    message.each do |m|
      @window.mvaddstr(line, startx, m)
      line+=1
    end  
    
    if player_health == 0
      if(@colours)
        @window.color_set(4, nil)
      end
      @window.mvaddstr(line+2, startx, "You have failed")
      if(@colours)
        @window.color_set(0, nil)
      end
    else
      if(@colours)
        @window.color_set(1, nil)
      end
      @window.mvaddstr(line+2, startx, "You have succeeded")
      if(@colours)
        @window.color_set(0, nil)
      end
    end
    
    @window.mvaddstr(line+4, startx, "Press any key to continue")
    
    @window.getch
  end
    
  def show(game, god = false, beginning_time = Time.now)
    
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
    map_height = lines[0]
    player_loc = game.player_loc
    map_x = player_loc[1] - map_width/2
    map_y = player_loc[2] - map_height/2
    
    player.look game
    (1..map_height).zip(map_y..(map_y+map_height)).each do |sy,gy|
      if gy < 0 || gy > game.level_width
        next
      end
      (0..map_width).zip(map_x..(map_x+map_width)).each do |sx,gx|
        tile, colour = player.show_tile(game, god, player_loc[0], gx, gy)
        if(@colours)
          @window.color_set(colour, nil)
        end
        if [player_loc[0], gx, gy] == @mark
          @window.attrset(Ncurses::A_REVERSE)
        end
        @window.mvaddstr(sy,sx, tile)
        if [player_loc[0], gx, gy] == @mark
          @window.attroff(Ncurses::A_REVERSE)
        end
      end
    end
    
    if(@colours)
      @window.color_set(0, nil)
    end
    
    #clear sidebar
    (0..lines[0]).each do |sy|
      @window.move(sy, map_width+1)
      @window.clrtoeol
    end
    
    #clear message bar
    @window.move(0, 0)
    @window.clrtoeol
    
    msg = player.last_msg
    unless msg.nil?
      @window.mvaddstr(0, 0, msg)
    end
    
    if game.game_over
      @window.attrset(Ncurses::A_REVERSE)
      @window.mvaddstr(1, 0, "Game Over")
      @window.attroff(Ncurses::A_REVERSE)
    end
    
    if player.more_messages? > 0
      if(@colours)
        @window.color_set(1, nil)
      end
      @window.mvaddstr(0, msg.length+1, "-more (#{player.more_messages?})-")
      if(@colours)
        @window.color_set(0, nil)
      end
    end
    
    #display sidebar
    side_start = map_width+2
    @window.mvaddstr(0, side_start, "Deck #{player_loc[0]+1}")
    room = game.room_for(*player_loc)
    @window.mvaddstr(1, side_start, "Room #{room[:number]} - #{room[:name]}") if room
      @window.mvaddstr(3, side_start, "Health: #{sprintf("%3d", player.health)}/#{player.max_health}")
    
    #show weapon
    @window.mvaddstr(5, side_start, "Weapon: ")
    if(player.weapon)
      @window.mvaddstr(7, side_start + 1, "Charge: #{sprintf("%3d", player.weapon.charge)}/#{player.weapon.max_charge}")
      @window.mvaddstr(6, side_start + 1, player.weapon.info)
    else
      @window.mvaddstr(6, side_start + 1, "None")
    end  
    
    #show armour
    @window.mvaddstr(8, side_start, "Armour: ")
    if(player.weapon)
      @window.mvaddstr(10, side_start + 1, "Charge: #{sprintf("%3d", player.armour.charge)}/#{player.armour.max_charge}") if player.armour.charge
      @window.mvaddstr(9, side_start + 1, player.armour.info)
    else
      @window.mvaddstr(9, side_start + 1, "None")
    end

    @window.mvaddstr(map_height-3, side_start, sprintf("               Turn: %5d", game.turn))
    @window.mvaddstr(map_height-2, side_start, sprintf(" Distance to border:  %2.1fly", (game.distance/1000)))
    @window.mvaddstr(map_height-1, side_start, sprintf("Distance of pursuit:   %2.1fly", -((game.capture_distance-game.distance)/1000)))
    
    @window.mvaddstr(19, side_start, "Objects #{game.object_count}")
    end_time = Time.now
    @window.mvaddstr(20, side_start, "Time #{((end_time - beginning_time)*1000).round} milliseconds")
    return player.more_messages? > 0
  ensure
    @mark = nil
    Ncurses.refresh
  end
  
end