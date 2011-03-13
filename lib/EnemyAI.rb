load "lib/Entity.rb"

class EnemyAI < Entity
  def initialize(rng, templates)
    super(rng, templates, :symbol => ['@', 4], :name => "Enemy Controller", :kind => :player, :mobile => false, :description => "The enemy AI")
  end
  
  def process(game, rng)
    messages = read_messages game
  end
end