require_relative "Offset"

include Offset

module Enemy
  def Enemy.process(game, rng, mob)
    mob.turn = if mob.turn then (mob.turn+1)%5 else rng.rand(4) end
    init_state = mob.state
    loc = game.loc_for(mob)
    if game.player_fov[loc]
      p_loc = game.player_loc
      lay_scent(mob, game, loc, p_loc)
      if mob.state != nil
        if fire_at(game, mob, loc, p_loc)
          mob.state = :attacking
        else
          follow_fov(game, rng, mob, loc, p_loc)
          mob.state = :chasing
        end
      else  
        mob.state = :attacking
      end
    else 
      follow_scent(game, rng, mob, loc)
      #state set in follow_scent
    end
    if init_state == nil && game.player_fov[game.loc_for(mob)]
      lay_scent(mob, game, loc, p_loc)
      lay_shout_scent(mob, game, loc)
      game.player << mob.stop_msg
      mob.state ||= :attacking
    end
  end
  
  private 
  
  def Enemy.fire_at(game, mob, loc, p_loc)
    return false if mob.fire_range < dist(*loc, *p_loc)
    return false if mob.weapon.charge == 0
    game.shoot(mob, p_loc)
  end
  
  def Enemy.fov_target(loc, game, p_loc)
    SURROUNDING.map{|x| Offset.offset loc, *x }.
      select{|x| game.player_fov[x] && !game.untraversable?(loc, x)}.
      sort_by{ |x| dist_sq(*game.player_loc, *x) }.first
  end
  
  def Enemy.lay_shout_scent(mob, game, loc)
    visited = Hash.new
    to_visit = [[loc, game.turn]]
    visited[loc] = true
    until to_visit.empty?
      curr = to_visit.shift
      game.scent(*curr)
      next if curr[1] == game.turn - 20
      SURROUNDING.map{ |x| Offset.offset(curr[0], *x) }.select{ |x| !visited[x] && !game.untraversable?(loc, x) }.each do |x|
        to_visit << [x, curr[1]-1]
        visited[x] = true
      end
    end
  end
  
  def Enemy.lay_scent(mob, game, loc, p_loc)
    tile = loc
    turns = 40
    val = game.turn
    begin
      if game.tile_at(*tile) == :hatch_open
        mob.seen_hatch = true
      end
      game.scent(tile, val)
      val+=1
      turns-=1
      tile = fov_target(tile, game, p_loc)
    end while tile && tile != p_loc && turns > 0
  end
  
  def Enemy.follow_fov(game, rng, mob, loc, p_loc)
    target_loc = fov_target(loc, game, p_loc)
    game.move(mob, *diff(*loc, *target_loc))
  end
  
  def Enemy.follow_scent(game, rng, mob, loc)
    candidates = game.scents_at loc
    if candidates.empty?
      return true if (game.player_loc[0] - loc[0]).abs > 1
      candidates = SURROUNDING_3D.map{|x| [x,0]}.shuffle
      if mob.likes == :hall
        mid = game.level_width/2
        candidates.select!{|x| closer_to_centre(x[0], loc, mid) || rng.rand(100) > 50}
      end
      mob.state = nil
    else
      mob.state = :following
    end
    
    candidates.select!{ |x,v| openable(mob, game).include?(game.tile_at(Offset.offset loc, *x)) || !game.untraversable?(loc, Offset.offset(loc, *x)) }
    if !candidates.empty?
      target = candidates[0][0]
      if openable(mob, game).include?(game.tile_at(Offset.offset loc, *target))
        if mob.state == :attacking
          mob.state = :chasing
          return true
        elsif mob.state == :chasing
          mob.state = :attacking
        end
        game.open(mob, target)
        if mob.state == nil
          game.scent(Offset.offset(loc, *target), game.turn - 29)
          game.scent(Offset.offset(Offset.offset(loc, *target), *target), game.turn - 28)
        end
      else
        fail "Can't move #{mob.info}, #{loc} to #{target}" unless game.move(mob, *target)
      end
    end
  end
  
  def Enemy.closer_to_centre(target_diff, loc, mid)
    y1 = loc[2] + target_diff[2]
    y2 = loc[2]
    (mid - y1).abs <= (mid - y2).abs
  end
  
  def Enemy.openable(mob, game)
    [:door,].concat(if game.ai.seen_hatch || mob.seen_hatch then [:hatch] else [] end)
  end
end