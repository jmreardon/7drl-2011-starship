require "yaml"
require "ncursesw"
load "lib/GameState.rb"
load "lib/Display.rb"
load "lib/Offset.rb"

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
    #attempt to load saved game
    @game = load_game() || new_game()
 
    @dsp = Display.new(colours)
    @dsp.window = Ncurses.stdscr
    
    action_result = :no_action
    begin
      if action_result != :no_action
        @game.process
      end
      messages = @dsp.show(@game) 
      #show multiple lines of messages
      if messages
        Ncurses.stdscr.getch
        action_result = :no_action
      else 
        action_result = process_input(Ncurses.stdscr.getch)
      end
    end while action_result
    
    File.open("saved_game.dat", "w") do |f|
      Marshal.dump(@game, f)
    end
  rescue Interrupt
    #do nothing
  ensure
    end_curses
  end
    
    

  private
  
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
    case action
    when nil
      @game.player << "Unbound key #{char}"
      return :no_action
    when :quit
      return false
    else 
      result = @game.act(@game.player, action)
      case result
      when :direction
        dir = get_direction
        if dir
          @game.act(@game.player, action, :dir => dir)
        else 
          return :no_action
        end
      when :target
        target = get_target
        if target
          @game.act(@game.player, action, :target => target)
        else 
          return :no_action
        end
      when false
        return :no_action
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
  
  def Main.load_game
    return false unless File.exists?("saved_game.dat")
    File.open("saved_game.dat", "r") do |f|
      Marshal.load(f)
    end
  end

  def Main.init
    Signal.trap("TERM") do
      end_curses
    end
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
  end
end