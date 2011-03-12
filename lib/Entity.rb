require "algorithms"

include Containers

class Entity
  attr_reader :description, :name, :symbol, :mobile, :kind, :actions
  
  def initialize(template)
    @description = template[:description] || (fail "No description for this entity: #{template}")
    @name = template[:name] || (fail "No name for this entity: #{template}")
    @symbol = template[:symbol] || (fail "No symbol for this entity: #{template}")
    @mobile = template[:mobile] || false
    @kind = template[:kind] || (fail "No kind for this entity: #{template}")
    @actions = template[:actions] || []
    @pending_messages = []
  end
  
  def <<(message, time=0)
    @pending_messages << [time, message]
  end
end