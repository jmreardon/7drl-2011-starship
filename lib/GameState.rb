require "yaml"

load "lib/MapBuilder.rb"
load "lib/Entity.rb"
load "lib/Player.rb"
load "lib/EnemyAI.rb"
load "lib/PermissiveFieldOfView.rb"

class GameState
  include PermissiveFieldOfView
  
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  attr_writer :config
  attr_reader :rooms, :level_width, :distance, :capture_distance, :warp_status, :turn
  def initialize(rng, config)
    @turn = 0
    @distance = 85000
    @capture_distance = 90000
    @warp_status = 1.0
    @rng = rng
    @config = config
    @ai = EnemyAI.new(rng, @config[:objects])
    data = MapBuilder.new.constructMap(rng, @config[:room_templates], @config[:objects])
    @mapData = data[:map]
    @level_width = data[:width]
    @height = data[:width]
    @width = data[:length]
    @rooms = data[:rooms]
    @player_seen = Hash.new(false)
    @player = Player.new(@rng, @config[:objects], @config[:objects][:player_marine])
    @objects = Hash.new
    @objects.compare_by_identity
    @objects[@player] = [0, find_floor(), @level_width/2]
    data[:objects].each do |obj, loc|
      next if @objects[@player] == loc
      @objects[obj] = loc
    end
    @locObjects = Hash.new
    @objects.each do |k,v|
      if @locObjects[v].nil?
        @locObjects[v] = Hash.new
      end
      @locObjects[v][k] = true
    end
  end
  
  def process
    @ai.process self, @rng
    @objects.each do |o,loc|
      o.process self, @rng
    end
    @distance -= @warp_status * 10
    @capture_distance -= 7
  end
  
  def object_count 
    @objects.size
  end
  
  def room_for(l, x, y)
    room = @rooms[l].find{|k,v| k[0]<=x && k[1]<=y && k[2] >=x && k[3] >= y}
    if room
      room[1]
    else 
      nil
    end
  end
  
  def player_seen?(l, x, y)
    return @player_seen[[l,x,y]]
  end
  
  def do_field_of_view(mob, range)
    @fov_level = @objects[mob][0]
    @fov_visible = Hash.new(false)
    @fov_player = mob == @player
    mob_loc = @objects[mob]
    do_fov(mob_loc[1], mob_loc[2], range)
    return @fov_visible
  end
  
  def light(x, y)
    @fov_visible[[@fov_level, x, y]] = true
    if @fov_player
      @player_seen[[@fov_level,x,y]] = tile_at(@fov_level,x,y)
    end
  end
  
  def blocked?(x, y)
    !@config[:untraversable][tile_at(@fov_level, x, y)].nil?
  end
  
  def act(mob, action, opts = {})
    case action
    when :cmd_up
      move mob, 0, 0, -1
    when :cmd_down
      move mob, 0, 0, 1
    when :cmd_left
      move mob, 0, -1, 0
    when :cmd_right
      move mob, 0, 1, 0
    when :cmd_up_left
      move mob, 0, -1, -1
    when :cmd_up_right
      move mob, 0, 1, -1
    when :cmd_down_left
      move mob, 0, -1, 1
    when :cmd_down_right
      move mob, 0, 1, 1
    when :cmd_lift_up
      move mob, 1, 0, 0
    when :cmd_lift_down
      move mob, -1, 0, 0
    when :cmd_shoot 
     if mob.weapon.nil?
       mob << "You need a weapon to fire"
       :no_action
     end
      if opts[:target] then shoot mob, opts[:target] else :target end
    when :cmd_open
      if opts[:dir] then open mob, opts[:dir] else :direction end
    when :cmd_close
      if opts[:dir] then close mob, opts[:dir] else :direction end
    when :cmd_activate
      if opts[:dir] then activate mob, opts[:dir] else :direction end
    when :cmd_login
      login mob, opts[:who]
    else 
      mob << "I don't know about action #{action}"
    end
  end
  
  def cmd_to_direction(cmd)
    case cmd
    when :cmd_up
      [0, 0, -1]
    when :cmd_down
      [0, 0, 1]
    when :cmd_left
      [0, -1, 0]
    when :cmd_right
      [0, 1, 0]
    when :cmd_up_left
      [0, -1, -1]
    when :cmd_up_right
      [0, 1, -1]
    when :cmd_down_left
      [0, -1, 1]
    when :cmd_down_right
      [0, 1, 1]
    else
      false
    end
  end
  
  def traversable?(mob, curr, loc)
    if curr[0] != loc[0] 
      return "There is no lift here" if tile_at(curr) != :lift
      return "The lift does not go there" if tile_at(loc) != :lift
      return "Lift in use" if !objects_at(loc).empty?
    end
    return "A #{objects_at(loc).first[0].name} is here" if !objects_at(loc).select{ |x,t| ![:item, :decor].include?(x.kind) }.empty? 
    return @config[:untraversable][tile_at(loc)]
  end
  
  def map_dimensions
    {:levels => 8, :length => @mapData[0][@level_width/2].length, :width => @mapData[0].length}
  end
  
  def player
    return @player
  end
  
  #stored in l,x,y
  def player_loc
    return @objects[@player]
  end
  
  def loc_for(obj)
    return @objects[obj]
  end
  
  def symbol_for(thing)
    @config[:mapSymbols][thing] || [nil, 0]
  end
  
  def symbol_at(*loc)
    objs = objects_at loc
    if !objs.nil? and objs.size > 0
      objs.sort_by{|x| obj_visibility x}.first.first.symbol || [nil, 0]
    else
      @config[:mapSymbols][tile_at(loc)] || [nil, 0]
    end
  end
  
  def obj_visibility(x)
    case x.first.kind
    when :creature
      0
    when :construct
      1
    when :item
      2
    when :decor
      3
    else
      4
    end
  end
  
  def objects_at(*loc)
    if(loc.size == 1)
      l = loc[0][0]
      x = loc[0][1]
      y = loc[0][2]
    else 
      l = loc[0]
      x = loc[1]
      y = loc[2]
    end
    return @locObjects[[l,x,y]] || {}
  end
  
  def tile_at(*loc)
    if(loc.size == 1)
      l = loc[0][0]
      x = loc[0][1]
      y = loc[0][2]
    else 
      l = loc[0]
      x = loc[1]
      y = loc[2]
    end
    val = if l < 0 or x < 0 or y < 0 or @mapData[l].nil? or @mapData[l][y].nil? or @mapData[l][y][x].nil?
        nil 
      else 
        @mapData[l][y][x] 
      end
    if val.nil? 
      :blank 
    else 
      val 
    end
  end
  
  private
  
  def offset(loc, l, x, y)
    return [loc[0]+l,loc[1]+x,loc[2]+y]
  end
  
  # for initial player placement
  def find_floor()
    floor = 0
    for x in 0..map_dimensions[:length]
      floor = x
      break if tile_at(0, x, map_dimensions[:width]/2) == :floor
    end
    return floor
  end
  
  
  #mob action definitions
  
  def close(mob, dir)
    open_close(mob, dir, [:door_open, :hatch_open], "There is nothing to close there", :door, :hatch)
  end
  
  def open(mob, dir)
    open_close(mob, dir, [:door, :hatch], "There is nothing to open there", :door_open, :hatch_open)
  end

  def open_close(mob, dir, to_use, nothing_msg, changed_door, changed_hatch)
    mob_loc = @objects[mob]
    loc = offset mob_loc, *dir
    if to_use.include?(tile_at(loc))
      @mapData[loc[0]][loc[2]][loc[1]] = if tile_at(loc) == to_use.first then changed_door else changed_hatch end
    else
      mob << nothing_msg
    end
  end
  
  def shoot(mob, loc)
    target = @locObjects[loc] && @locObjects[loc].find{ |x,t| ![:item, :decor].include?(x.kind) }
    if target
      return true unless check_weapon(mob, mob.weapon)
      target = target[0]
      mob.last_target = target
      hit target, mob.weapon, mob
    else
      mob << "Nothing there to shoot"
      :no_action
    end
  end
  
  def check_weapon(mob, weapon)
    if weapon.charge == 0
      mob << "Hrm, no charge"
      return false
    else
      weapon.charge-=1
      return true
    end
  end
  
  def hit(target, weapon, shooter)
    damage = @rng.rand(weapon.dam[0]..weapon.dam[1])
    target.health -= damage
    if target.health <= 0
      kill target
      shooter << "You #{killed target} the #{target.name}"
    else 
      shooter << "You #{damage_msg target, damage, target.max_health} the #{target.name}"
    end
  end
  
  def kill(target)
    loc = @objects[target]
    @locObjects[@objects[target]].delete(target)
    @objects.delete(target)
    if target.kill_template
      object = Entity.new(@rng, @config[:objects], @config[:objects][target.kill_template])
      @objects[object] = loc
      place_mob(loc, object)
    end
  end
  
  def killed(target)
    if target.kind == :creature
      "kill"
    else 
      "destroy"
    end
  end
  
  def damage_msg(target, dam, max)
    percent = dam/max.to_f
    if percent < 0.05
      "graze"
    elsif percent < 0.2
      if target.kind == :creature then "hurt" else "damage" end
    elsif percent < 0.5
      "blast"
    else
      if target.kind == :creature then "cripple" else "wreck" end
    end
  end
  
  def move(mob, l, x, y)
    unless mob.mobile
      mob << "You are not mobile, you cannot move"
      return false
    end
    
    mob_loc = @objects[mob]
    next_loc = offset mob_loc, l, x, y
    
    #check for interactions besides moving later
    
    
    traversable_msg = traversable?(mob, mob_loc, next_loc)
    unless traversable_msg.nil?
      mob << traversable_msg
      return false
    end
    
    @locObjects[mob_loc].delete(mob)
    place_mob(next_loc, mob)
    @objects[mob] = next_loc
  end
  
  def place_mob(loc, mob)
    @locObjects[loc] = Hash.new if @locObjects[loc].nil?
    @locObjects[loc][mob] = true
  end

  def login(mob, controller)
    controller << "Attempting to log in..." << "Lockout in effect. This access has been reported to security.".upcase
    @ai << [:intruder, @objects[mob]]
  end
  
  def activate(mob, dir)
    mob_loc = @objects[mob]
    target_loc = offset mob_loc, *dir
  
    target = @locObjects[target_loc].find{ |x,t| x.action }
    if target
      act target[0], target[0].action, :who => mob
    else
      mob << "There is nothing to active there"
    end
  end
  
end