load "lib/Entity.rb"

class Player < Entity
  attr_reader :old_msgs
  def initialize(template)
    super(template)
    @old_msgs = []
  end
  
  def last_msg
    if @pending_messages[-1].nil?
      ""
    else 
      @old_msgs << @pending_messages.pop
      @old_msgs[-1][1]
    end
  end
end