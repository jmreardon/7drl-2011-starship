
require "rubygems"
require "bundler/setup"

require "yaml"
require "ncursesw"
load "lib/GameState.rb"
load "lib/Display.rb"

module Main
  def Main.start
    init()
    begin
      Ncurses.initscr
      Ncurses.cbreak           # provide unbuffered input
      Ncurses.noecho           # turn off input echoing
      Ncurses.nonl             # turn off newline translation
      Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
      Ncurses.stdscr.keypad(true)
      Ncurses.curs_set(0)
      
      #attempt to load saved game
      @game = load_game() || new_game()
      File.open("saved_game.dat", "w") do |f|
        Marshal.dump(@game, f)
      end

      dsp = Display.new
      dsp.window = Ncurses.stdscr
      begin
        dsp.show(@game) 
      end while process_input(Ncurses.stdscr.getch)

    ensure
      Ncurses.echo
      Ncurses.nocbreak
      Ncurses.nl
      Ncurses.endwin
    end
    
    dims = @game.map_dimensions
    player = @game.player_loc
    puts player.to_s
    File.open("levels.txt", "w") do |f|
      i = 1
      for l in 0...dims[:levels]
        f.puts "Level #{i}"
        for y in 0...dims[:width]
          for x in 0...dims[:length]
            f.print(@game.symbol_at(l,x,y))
          end
          f.puts ""
        end  
        f.puts ""
        f.puts ""
        i+=1
      end
    end
  end

  private
  
  def Main.process_input(char)
    action = @keyBindings[char]
    case action
    when nil
      @game.player << "Unbound key #{char}"
    when :quit
      return false
    else 
      @game.act(@game.player, action)
    end
    return true
  end
  
  def Main.new_game
    Ncurses.stdscr.addstr("Generating new game")
    return GameState.new(Random.new, @config)
  end
  
  def Main.load_game
    return false unless File.exists?("saved_game.dat")
    File.open("saved_game.dat", "r") do |f|
      Marshal.load(f)
    end
  end

  def Main.init
    #load keybindings
    fail "Cannot load configuration file (config.yml)" unless File.exists?("config.yml")
    @config = YAML.load_file("config.yml")

    fail "Cannot load keybindings (keybindings.yml)" unless File.exists?("keybindings.yml")
    @keyBindings = Hash.new
    YAML.load_file("keybindings.yml").each do |key,action|
      if Ncurses.const_defined?(key.to_sym)
        key = Ncurses.const_get(key.to_sym)
      elsif key.respond_to?(:length) && key.length == 1
        key = key.ord
      elsif key.class != Fixnum
        fail "Invalid key: #{key} used to bind #{action}"
      end
      @keyBindings[key] = action.to_sym
    end
  rescue RuntimeError => e  
    puts e.message
  end
end