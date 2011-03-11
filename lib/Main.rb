
require "rubygems"
require "bundler/setup"

require "yaml"
require "ncursesw"
load "lib/GameState.rb"
load "lib/random.rb"

module Main
  def Main.start
    begin
      #load keybindings
      fail "Cannot load configuration file (config.yml)" unless File.exists?("config.yml")
      config = YAML.load_file("config.yml")

      fail "Cannot load keybindings (keybindings.yml)" unless File.exists?("keybindings.yml")
      keyBindings = Hash.new
      YAML.load_file("keybindings.yml").each do |key,action|
        if Ncurses.const_defined?(key.to_sym)
          key = Ncurses.const_get(key.to_sym)
        elsif key.length == 1
          key = key.each_byte.first
        else
          fail "Invalid key: #{key} used to bind #{action}"
        end
        keyBindings[key] = action.to_sym
      end

      rng = Random.new
      state = GameState.new(rng)
      exit
      begin
        Ncurses.initscr
        Ncurses.cbreak           # provide unbuffered input
        Ncurses.noecho           # turn off input echoing
        Ncurses.nonl             # turn off newline translation
        Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
        Ncurses.stdscr.keypad(true)

        Ncurses.stdscr.addstr("Press a key to continue") # output string
        result = Ncurses.stdscr.getch

      ensure
        Ncurses.echo
        Ncurses.nocbreak
        Ncurses.nl
        Ncurses.endwin
      end

      puts result
      mapData = Hash.new
      puts "RNG seed: #{rng.seed}"

      mapData = MapBuilder.new.constructMap(rng)
      puts mapData[:rooms][0].to_s

      File.open("levels.txt", "w") do |f|
        i = 1
        for l in mapData[:map]
          f.puts "Level #{i}"
          for y in l
            if !y.nil?
              for x in y
                f.print(case x
                  when nil
                    ' '
                  when :floor
                    '.'
                  when :door
                    '+'
                  when :wall
                    '#'
                  when :lift
                    'o'
                  when :hatch
                    '='
                  end)
              end
            else 
              f.puts ""
            end  
            f.puts ""
          end  
          f.puts ""
          f.puts ""
          i+=1
        end
      end

    rescue RuntimeError => e  
      puts e.message
    end
  end
  
  
end