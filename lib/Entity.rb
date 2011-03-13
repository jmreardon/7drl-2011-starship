require "algorithms"

include Containers

class Entity
  attr_reader :description, 
              :name, 
              :symbol, 
              :mobile, 
              :kind, 
              :weapon, 
              :capabilities, 
              :max_health,
              :max_charge
  attr_accessor :health, 
                :charge
  attr_accessor :last_target
  
  def initialize(rng, templates, template)
    @template = template
    @description = template[:description] || (fail "No description for this entity: #{template}")
    @name = template[:name] || (fail "No name for this entity: #{template}")
    @symbol = template[:symbol] || (fail "No symbol for this entity: #{template}")
    @mobile = template[:mobile] || false
    @kind = template[:kind] || (fail "No kind for this entity: #{template}")
    @weapon = select_weapon(rng, template[:weapon], templates)
    @health = select_health(rng, template[:health])
    @max_health = @health
    @charge = template[:charge]
    @max_charge = @charge
    @capabilities = template[:capabilities] || []
    @pending_messages = []
  end
  
  def method_missing(id, *args)
    raise NoMethodError if args.size > 0
    return nil if !@template.has_key?(id)
    return @template[id]
  end
  
  def info
    @name + " " + capabilities.map{ |c| capability_stat(c) }.select{|x| !x.nil?}.join(", ")
  end
  
  def capability_stat(c)
    case c
    when :weapon
      "[#{self.dam.join("-")}]"
    else
      nil
    end
  end
  
  def read_messages(game)
    remaining, to_read = @pending_messages.partition{ |t,m| t > game.turn }
    @pending_messages = remaining
    to_read.map{ |t,m| m }.select{|m| m.kind_of?(Array)}
  end
  
  def process(game, rng)
    
  end
  
  def <<(message, time=-1)
    @pending_messages << [time, message]
    self
  end
  
  private
  
  def select_health(rng, range)
    if range.nil? then 10 else rng.rand(range[0]..range[1]) end
  end
  
  def select_weapon(rng, weapon_options, templates)
    return nil if weapon_options.nil?
    weapon = weapon_options[rng.rand(weapon_options.size)]
    fail "Cannot identify weapon: #{weapon}" if templates[weapon].nil?
    return Entity.new(rng, templates, templates[weapon])
  end
end