# Copyright 2011 Justin Reardon
#
# This file is part of 'Storming the Ship'.
# 
# Storming the Ship is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Storming the Ship is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Storming the Ship.  If not, see <http://www.gnu.org/licenses/>.

require "yaml"
require "backports/1.9"
require "ncursesw"
require_relative "GameState"
require_relative "Display"
require_relative "Offset"

module Main
  
  def Main.start
    init()
    Ncurses.initscr
    Ncurses.cbreak           # provide unbuffered input
    Ncurses.noecho           # turn off input echoing
    Ncurses.nonl             # turn off newline translation
    Ncurses.stdscr.keypad(true)
    Ncurses.curs_set(0)
    colours = false
    if Ncurses.has_colors?
      bg = Ncurses::COLOR_BLACK
      Ncurses.start_color
      if (Ncurses.respond_to?("use_default_colors"))
        if (Ncurses.use_default_colors == Ncurses::OK)
          bg = -1
        end
      end
      Ncurses.init_pair(0, Ncurses::COLOR_WHITE, bg);
      Ncurses.init_pair(1, Ncurses::COLOR_GREEN, bg);
      Ncurses.init_pair(2, Ncurses::COLOR_YELLOW, bg);
      Ncurses.init_pair(3, Ncurses::COLOR_MAGENTA, bg);
      Ncurses.init_pair(4, Ncurses::COLOR_RED, bg);
      Ncurses.init_pair(5, Ncurses::COLOR_CYAN, bg);
      colours = true
    end
    
    #this is the game loop
    action_result = :no_action
    #attempt to load saved game
    beginning_time = Time.now
    @game = load_game(@config)
    @dsp = Display.new(colours)
    @dsp.window = Ncurses.stdscr
    begin
      if !@game || action_result == :game_over
       @dsp.new_game
       @game = new_game()
     end
    
      
      begin
        if action_result != :no_action && @game.player.health > 0
          @game.process
        end
        #save_game
        messages = @dsp.show(@game, @god, beginning_time) 
        #show multiple lines of messages
        if messages
          Ncurses.stdscr.getch
          action_result = :no_action
        else 
          action_result = process_input(Ncurses.stdscr.getch)
        end
        beginning_time = Time.now
      end while action_result && action_result != :game_over
      @dsp.game_over(@game.game_over, @game.player.health) if @game.game_over
      Ncurses.clear
    end while action_result
    if @game
      save_game
    end
  rescue Interrupt
    #do nothing
  ensure
    end_curses
  end
    
    

  private
  
  def Main.save_game
    return false unless @game
    File.open("saved_game.dat", "w") do |f|
      Marshal.dump(@game, f)
    end
  end
    
  def Main.end_curses
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
  end
  
  def Main.process_input(char)
    case char
    when Ncurses::KEY_RESIZE
      return :no_action
    end
    action = @keyBindings[char]
    if @game.game_over && action == :cmd_esc
      return :game_over
    end
    case action
    when nil
      #@game.player << "Unbound key #{char}"
      return :no_action
    when :quit
      return false
    when :cmd_god
      @god = !@god
      return :no_action
    else 
      result = @game.act(@game.player, action)
      case result
      when :direction
        dir = get_direction
        if dir
          return @game.act(@game.player, action, :dir => dir)
        else 
          return :no_action
        end
      when :target
        target = get_target
        if target
          return @game.act(@game.player, action, :target => target)
        else 
          return :no_action
        end
      when false
        return :no_action
      else
        return result
      end
    end
    return :action
  end
  
  def Main.get_direction
    begin
      @dsp.show(@game)
      action = @keyBindings[Ncurses.stdscr.getch]
      
      return false if action == :cmd_esc
      dir = @game.cmd_to_direction(action)
      return dir if dir
      @game.player << "Direction? (use the direction keys)"
    end while true
  end

  def Main.get_target
    player = @game.player
    loc = @game.loc_for(player.last_target)
    if loc == nil || !player.see?(*loc)
      loc = @game.player_loc
    end
    dir = [0,0,0]
    begin
      if dir && player.see?(*Offset.offset(loc, *dir))
        loc = Offset.offset loc, *dir
        player << @game.description_at(*loc)
      elsif dir.nil? || !dir.kind_of?(Array)
        player << "Use the direction keys to select a target"
      elsif !player.see?(*Offset.offset(loc, *dir))
        @game.player << "You can't see there"
      end

      @dsp.mark(loc)
      @dsp.show(@game)
      
      action = @keyBindings[Ncurses.stdscr.getch]
      return false if action == :cmd_esc
      return loc if action == :cmd_enter
      dir = @game.cmd_to_direction(action)
    end while true
  end
  
  def Main.new_game
    return GameState.new(Random.new, @config)
  end
  
  def Main.load_game(config)
    return false unless File.exists?("saved_game.dat")
    loaded = File.open("saved_game.dat", "r") do |f|
      Marshal.load(f)
    end
    loaded.config = @config
    File.delete("saved_game.dat")
    loaded
  end

  def Main.init
    Signal.trap("TERM") do
      save_game
      end_curses
    end
    @god = false
    #load keybindings
    fail "Cannot load configuration file (config.yml)" unless File.exists?("config.yml")
    @config = YAML.load_file("config.yml")

    fail "Cannot load keybindings (keybindings.yml)" unless File.exists?("keybindings.yml")
    @keyBindings = Hash.new
    YAML.load_file("keybindings.yml").each do |key,action|
      if key.respond_to?(:length) && key.length == 1
      key = key.ord
      elsif key.class != Fixnum && Ncurses.const_defined?(key.to_sym)
        key = Ncurses.const_get(key.to_sym)
      elsif key.class != Fixnum
        fail "Invalid key: #{key} used to bind #{action}"
      end
      @keyBindings[key] = action.to_sym
    end
  rescue RuntimeError => e  
    puts e.message
    fail e
  ensure
    save_game
  end
end
