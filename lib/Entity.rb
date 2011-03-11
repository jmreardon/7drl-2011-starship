require "algorithms"

include Comtainers

class Entity
  attr_reader :description, :name, :symbol
  
  def initialize(template)
    @description = template[:description]
    @name = template[:name]
    @symbol = template[:symbol]
    @pending_messages = Heap.new
  end
  
  def <<(message, time=0)
    @pending_messages.push(time, message)
  end
end