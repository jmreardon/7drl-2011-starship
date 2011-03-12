require "algorithms"

include Containers

class Entity
  attr_reader :description, :name, :symbol, :mobile
  
  def initialize(template)
    @description = template[:description]
    @name = template[:name]
    @symbol = template[:symbol]
    @mobile = template[:mobile] || false
    @pending_messages = []
  end
  
  def <<(message, time=0)
    @pending_messages << [time, message]
  end
end