load "lib/Entity.rb"

class EnemyAI < Entity
  def initialize(rng)
    super(:symbol => ['@', 4], :name => "Enemy Controller", :kind => :player, :mobile => false, :description => "The enemy AI")
    @rng = rng
  end
end