require "yaml"

class Random
  def to_yaml(io)
    self.marshal_dump.to_yaml(io)
  end
end