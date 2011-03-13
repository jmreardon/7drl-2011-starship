require_relative "Offset"

include Offset

module Enemy
  def Enemy.process(game, rng, mob)
    mob.turn = if mob.turn then (mob.turn+1)%5 else 1 end
    loc = game.loc_for(mob)
    candidates = game.scents_at loc
    if candidates.empty?
      candidates = SURROUNDING_3D.map{|x| [x,0]}.shuffle
    end
    
    candidates.select!{ |x,v| openable(mob, game).include?(game.tile_at(Offset.offset loc, *x)) || !game.untraversable?(mob, loc, Offset.offset(loc, *x)) }
    if !candidates.empty?
      target = candidates[0][0]
      if openable(mob, game).include?(game.tile_at(Offset.offset loc, *target))
        game.open(mob, target)
      else
        fail "Can't move #{mob.info}, #{loc} to #{target}" unless game.move(mob, *target)
      end
    else
      fail "no candidates"
    end
  end
  
  private 
  
  def Enemy.openable(mob, game)
    [:door]
  end
end