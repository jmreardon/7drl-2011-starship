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

require_relative "MapBuilder"
require_relative "Entity"
require_relative "Player"
require_relative "EnemyAI"
require_relative "Offset"
require_relative "PermissiveFieldOfView"

include Offset

class GameState
  include PermissiveFieldOfView
  
  attr_writer :config
  attr_reader :rooms, :level_width, :distance, :capture_distance, :warp_status, :turn, :player_fov, :ai, :game_over
  def initialize(rng, config)
    @game_over = nil
    @shield_damage = 0
    @turn = 0
    @distance = 16000
    @capture_distance = 9000
    @warp_status = 1.0
    @rng = rng
    @config = config
    data = false
    until data
    @objects = Hash.new
      data = MapBuilder.new.constructMap(self, rng, @config[:room_templates], @config[:objects])
    end
    @ai = EnemyAI.new(self, rng, @config[:objects])
    @mapData = data[:map]
    @level_width = data[:width]
    @height = data[:width]
    @width = data[:length]
    @rooms = data[:rooms]
    @player_seen = Hash.new(false)
    @player_fov = Hash.new(false)
    @player = Player.new(self, @rng, @config[:objects], @config[:objects][:player_marine])
    @objects[@player] = [0, *find_floor()]
    @scent_map = Hash.new(-1)
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
  
  def add_item(obj)
    @objects[obj] = nil
  end
  
  def process
    @player.look self
    @ai.process self, @rng
    @objects.each do |o,loc|
      break if @player.health == 0 || @game_over
      o.process self, @rng
    end
    @distance -= @warp_status * 10
    @capture_distance -= 7
    @turn+=1
    if @capture_distance < 0
      @player << "Friendly vessels have intercepted the ship"
      @game_over = @config[:ending][:capture]
    end
    if @player.health == 0 && !@game_over
      @game_over = @config[:ending][:killed]
    end
  end
  
  def scent(loc, val, override = false)
    @scent_map[loc] = if override then val else [@scent_map[loc], val].max end
  end
  
  def scents_at(loc)
    (if tile_at(loc) == :lift then SURROUNDING_3D else SURROUNDING end).map{ |l,x,y| [[l,x,y], @scent_map[Offset.offset(loc, l, x, y)]] }.
    select{ |loc,val| val >= [@turn-30, 0].max }.
    sort {|a,b| b[1] <=> a[1]} 
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
    if @fov_player
      @player_fov = @fov_visible
    end
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
    if (mob == @player && mob.health && mob.health == 0) || @game_over
      if action == :cmd_examine
        if opts[:target]
          mob.last_target = @locObjects[opts[:target]] && !@locObjects[opts[:target]].empty? && @locObjects[opts[:target]].sort_by{|x| obj_visibility x}.first.first
          mob << "#{mob.last_target.info}: #{mob.last_target.description}" if mob.last_target
          return :no_action 
        else 
          return :target
        end
      else
        mob << "The game is over, press the escape-action key to play again"
        return :no_action
      end
    end
    case action
    when :cmd_rest
      return :action
    when :cmd_equip
      equip mob
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
    when :cmd_examine
      if opts[:target]
        mob.last_target = @locObjects[opts[:target]] && !@locObjects[opts[:target]].empty? && @locObjects[opts[:target]].sort_by{|x| obj_visibility x}.first.first
        mob << "#{mob.last_target.info}: #{mob.last_target.description}" if mob.last_target
        :no_action 
      else 
        :target
        end
    when :cmd_open
      if opts[:dir] then open mob, opts[:dir] else :direction end
    when :cmd_close
      if opts[:dir] then close mob, opts[:dir] else :direction end
    when :cmd_activate
      if opts[:dir] then activate mob, opts[:dir] else :direction end
    when :cmd_login
      login mob, opts[:who]
    when :cmd_charge
      charge mob, opts[:who]
    when :destroy_ship
      @game_over = if (@shield_damage < 3 || @warp_status == 0)
        mob << "You have caused a reactor core breach"
        @config[:ending][:core_breach]
      else 
        mob << "You have disabled the shields"
        @config[:ending][:shield_failure]
      end
    when :warp_damage
      mob << "Warp speed reduced"
      @warp_status = [0, warp_status - 0.4].max
    when :shield_damage
      @shield_damage+=1
      if @shield_damage > 2 && @warp_status > 0
        act mob, :destroy_ship
      end
    when :leader_dead  
        mob << "Seeing their commander die, the rebels surrender"
      @game_over = @config[:ending][:leader_dead]
    else 
      #mob << "I don't know about action #{action}"
      :no_action
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
  
  def untraversable?(curr, loc)
    if curr[0] != loc[0] 
      return "There is no lift here" if tile_at(curr) != :lift
      return "The lift does not go there" if tile_at(loc) != :lift
      return "Lift in use" if !objects_at(loc).empty?
    end
    return "A #{objects_at(loc).first[0].name} is here" if !objects_at(loc).select{ |x,t| ![:item, :decor].include?(x.kind) }.empty? 
    # return the untraversable tile message, of course, if it is traversable, this is nil
    return @config[:untraversable][tile_at(loc)]
  end
  
  def map_dimensions
    {:levels => 8, :length => @mapData[4][@level_width/2].length, :width => @mapData[4].length}
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
  
  def description_at(*loc)
    objs = objects_at loc
    if !objs.nil? && objs.size > 0
      obj = objs.sort_by{|x| obj_visibility x}.first.first
      obj.info
    else
      case tile_at(*loc)
      when :floor
        "The floor"
      when :wall
        "A wall"
      when :door, :door_open
        "A door"
      when :hatch, :hatch_open
        "A hatch"
      when :lift
        "A lift"
      else
        "Nothing of note here"
      end
    end
  end
  
  def symbol_at(*loc)
    objs = objects_at loc
    if !objs.nil? && objs.size > 0
      objs.sort_by{|x| obj_visibility x}.first.first.symbol || [nil, 0]
    else
      @config[:mapSymbols][tile_at(*loc)] || [nil, 0]
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
  
  #mob action definitions
  
  def equip(mob)
    loc = @objects[mob]
    target = @locObjects[loc] && @locObjects[loc].find{ |x,t| x.capabilities.include?(:armour) || x.capabilities.include?(:weapon)}
    if target
      item = target[0]
      @locObjects[loc].delete(item)
      old = nil
      if item.capabilities.include?(:weapon)
        old = mob.weapon
        mob.weapon = item
      else 
        old = mob.armour
        mob.armour = item
      end
      mob << "Equiped #{item.info}"
      place_mob(loc, old)
      @objects[item] = nil
      :action
    else
      mob << "Nothing to pick up here"
      :no_action
    end
  end
  
  def close(mob, dir)
    open_close(mob, dir, [:door_open, :hatch_open], "There is nothing to close there", :door, :hatch)
  end
  
  def open(mob, dir)
    open_close(mob, dir, [:door, :hatch], "There is nothing to open there", :door_open, :hatch_open)
  end

  def open_close(mob, dir, to_use, nothing_msg, changed_door, changed_hatch)
    mob_loc = @objects[mob]
    loc = Offset.offset mob_loc, *dir
    if to_use.include?(tile_at(loc))
      @mapData[loc[0]][loc[2]][loc[1]] = if tile_at(loc) == to_use.first then changed_door else changed_hatch end
    else
      mob << nothing_msg
      :no_action
    end
  end
  
  def shoot(mob, loc)
    target = @locObjects[loc] && @locObjects[loc].find{ |x,t| ![:item, :decor].include?(x.kind) && x.health != 0 }
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
  
  def move(mob, l, x, y)
    unless mob.mobile
      mob << "You are not mobile, you cannot move"
      return false
    end
    
    mob_loc = @objects[mob]
    next_loc = Offset.offset mob_loc, l, x, y
    
    #check for target to attack
    objs = @locObjects[next_loc]
    if objs && target = objs.find{ |x,t| x.kind == :creature }
      return hit(target[0], mob.weapon, mob)
    end
    
    traversable_msg = untraversable?(mob_loc, next_loc)
    unless traversable_msg.nil?
      mob << traversable_msg
      return false
    end
    
    if mob == @player
      @scent_map[next_loc] = @turn
      if objs && !objs.empty?
        mob << "On the ground: #{objs.map{|x| x[0].info}.join("; ")}"
      end
    end
    @locObjects[mob_loc].delete(mob)
    place_mob(next_loc, mob)
    @objects[mob] = next_loc
  end
  
  private
  
  # for initial player placement
  def find_floor()
    fx = 0
    fy = 0
    for y in 0..map_dimensions[:width]
      fy = y
      for x in 0..map_dimensions[:length]
        fx = x
        break if tile_at(0, x, y) == :floor
      end  
      break if tile_at(0, x, y) == :floor
    end
    return [fx, fy]
  end
  
  def check_weapon(mob, weapon)
    if weapon.charge == 0
      mob << "Hrm, no charge"
      return false
    else
      return true
    end
  end
  
  def hit(target, weapon, shooter)
    damage = if weapon.charge && weapon.charge > 0 
      @rng.rand(weapon.dam[0]..weapon.dam[1])
    else
      @rng.rand(weapon.melee_dam) + shooter.strength
    end
    damage = [1, damage].max
    #handle armour
    if target.armour
      if target.armour.charge && target.armour.charge > 0
        neg = @rng.rand(target.armour.dr_charge[0]..target.armour.dr_charge[1])
        target.armour.add_charge(-1)
      else
        neg = @rng.rand(target.armour.dr[0]..target.armour.dr[1])
      end
      damage = [0, damage - neg].max
    end
    weapon.charge-=1 if weapon.charge && weapon.charge > 0
    target.health = [target.health - damage, 0].max
    if target.health <= 0
      shooter << "You #{killed target} the #{target.name}"
      target << "You are killed by #{shooter.name}"
      kill target
      if target.kill_flag
        act shooter, target.kill_flag
      end
      :action
    elsif damage == 0
      shooter << "You hit the #{target.name} to no effect!"
      target << "You are hit by the #{shooter.name} to no effect."
    else
      shooter << "You #{damage_msg target, damage, target.max_health} the #{target.name}"
      target << "You are attacked by the #{shooter.name} for #{damage} hp"
    end
  end
  
  def kill(target)
    return if target == @player
    loc = @objects[target]
    @locObjects[@objects[target]].delete(target)
    items = target.items
    @objects.delete(target)
    if target.kill_template
      object = Entity.new(self, @rng, @config[:objects], @config[:objects][target.kill_template])
      @objects[object] = loc
      place_mob(loc, object)
    elsif !items.empty? && @rng.rand(100) > 50
      item = items[@rng.rand(items.size)]
      items.each do |i|
        next if i == item
        @objects.delete(i)
      end
      place_mob(loc, item)
    else 
      items.each do |i|
        next if i == item
        @objects.delete(i)
      end
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
  
  def place_mob(loc, mob)
    @locObjects[loc] = Hash.new if @locObjects[loc].nil?
    @locObjects[loc][mob] = true
  end
  
  def charge(mob, controller)
    curr_charge = mob.charge
    if curr_charge == 0
      controller << "Power reserves depleted, please try again later".upcase
      return :action
    end
    to_charge = controller.items.select{ |x| !x.charge.nil? }
    if to_charge.empty?
      controller << "You have nothing to charge"
    elsif to_charge.all?{ |x| x.charge == x.max_charge }
      controller << "Everything is already fully charged"
    else
      to_charge.each do |x|
        curr_charge = x.add_charge curr_charge
      end
      mob.add_charge(curr_charge - mob.charge)
      if to_charge.all?{ |x| x.charge == x.max_charge }
        controller << "Everything is now fully charged"
      else
        controller << "You deplete the charger's power reserves"
      end
    end
  end
      

  def login(mob, controller)
    controller << "Attempting to log in..." << "Lockout in effect. This access has been reported to security.".upcase
    @ai << [:intruder, @objects[mob]]
  end
  
  def activate(mob, dir)
    mob_loc = @objects[mob]
    target_loc = Offset.offset mob_loc, *dir
  
    target =  @locObjects[target_loc] && @locObjects[target_loc].find{ |x,t| x.action }
    if target
      act target[0], target[0].action, :who => mob
    else
      mob << "There is nothing to active there"
    end
  end
  
end