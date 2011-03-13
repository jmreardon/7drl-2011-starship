require_relative "Offset"

include Offset

module Enemy
  def Enemy.process(game, rng, mob)
    mob.turn = if mob.turn then (mob.turn+1)%5 else 1 end
    loc = game.loc_for(mob)
    if game.player_fov[loc]
      follow_fov(game, rng, mob, loc)
      lay_scent(game, loc)
    else 
      follow_scent(game, rng, mob, loc)
    end
  end
  
  private 
  
  def Enemy.lay_scent(game, loc)
    p_loc = game.player_loc
    tile = loc
    turns = 40
    val = game.turn
    begin
      game.scent(tile, val)
      val+=1
      turns-=1
      tile = SURROUNDING.map{|x| Offset.offset tile, *x }.
        select{|x| game.player_fov[x] && !game.untraversable?(tile, x)}.
        sort_by{ |x| dist_sq(*p_loc, *x)}.first
    end while tile != p_loc && turns > 0
  end
  
  def Enemy.follow_fov(game, rng, mob, loc)
    p_loc = game.player_loc
    target_loc = SURROUNDING.map{|x| Offset.offset loc, *x }.
      select{|x| game.player_fov[x] && !game.untraversable?(loc, x)}.
      sort_by{ |x| dist_sq(*p_loc, *x)}.first
    game.move(mob, *diff(*loc, *target_loc))
  end
  
  def Enemy.follow_scent(game, rng, mob, loc)
    candidates = game.scents_at loc
    if candidates.empty?
      candidates = SURROUNDING_3D.map{|x| [x,0]}.shuffle
    end
    
    candidates.select!{ |x,v| openable(mob, game).include?(game.tile_at(Offset.offset loc, *x)) || !game.untraversable?(loc, Offset.offset(loc, *x)) }
    if !candidates.empty?
      target = candidates[0][0]
      if openable(mob, game).include?(game.tile_at(Offset.offset loc, *target))
        game.open(mob, target)
        game.scent(Offset.offset(loc, *target), game.turn - 29)
        game.scent(Offset.offset(Offset.offset(loc, *target), *target), game.turn - 28)
      else
        fail "Can't move #{mob.info}, #{loc} to #{target}" unless game.move(mob, *target)
      end
    end
  end
  
  def Enemy.openable(mob, game)
    [:door]
  end
end