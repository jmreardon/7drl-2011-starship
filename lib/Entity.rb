# Copyright 2011 Justin Reardon
#
# This file is part of 'Storming the Ship'.
# 
# Storming the Ship is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Storming the Ship is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Storming the Ship.  If not, see <http://www.gnu.org/licenses/>.

require_relative "Enemy"

class Entity
  attr_reader :description, 
              :name, 
              :symbol, 
              :mobile, 
              :kind, 
              :capabilities, 
              :max_health,
              :max_charge
  attr_accessor :health, 
                :charge,
                :weapon, 
                :armour
  attr_accessor :last_target
  
  def initialize(game, rng, templates, template)
    @template = template
    @description = template[:description] || (fail "No description for this entity: #{template}")
    @name = template[:name] || (fail "No name for this entity: #{template}")
    @symbol = template[:symbol] || (fail "No symbol for this entity: #{template}")
    @mobile = template[:mobile] || false
    @kind = template[:kind] || (fail "No kind for this entity: #{template}")
    @weapon = select_item(game, rng, template[:weapon], templates)
    @armour = select_item(game, rng, template[:armour], templates)
    @health = select_health(rng, template[:health])
    @max_health = @health
    @charge = template[:charge]
    @max_charge = @charge
    @capabilities = template[:capabilities] || []
    @pending_messages = []
    @props = Hash.new
    for i in items
      game.add_item i
    end
  end
  
  def add_charge(add)
    diff = [0, (@charge+add) - @max_charge].max
    @charge = [0, [@max_charge, @charge+add].min].max
    return diff
  end
  
  def items
    items = []
    items << weapon unless weapon.nil?
    items << armour unless armour.nil?
    items
  end
  
  def method_missing(id, *args)
    raise NoMethodError if args.size > 1
    if args.size == 1 && id[-1] == "="
      @props[id.to_s.chop.to_sym] = args[0]
    elsif args.size == 0
      @props[id] || @template[id]
    end
  end
  
  def info
    @name + " " + capabilities.map{ |c| capability_stat(c) }.select{|x| !x.nil?}.join(", ")
  end
  
  def capability_stat(c)
    case c
    when :weapon
      "[#{self.dam.join("-")}]"
    when :armour
      "[#{self.dr.join("-")}" + (if self.dr_charge then "/#{self.dr_charge.join("-")}]" else "]" end)
    else
      nil
    end
  rescue NoMethodError
  end
  
  def read_messages(game)
    remaining, to_read = @pending_messages.partition{ |t,m| t > game.turn }
    @pending_messages = remaining
    to_read.map{ |t,m| m }.select{|m| m.kind_of?(Array)}
  end
  
  def process(game, rng)
    capabilities.each { |x| process_capability game, rng, x }
  end
  
  def process_capability(game, rng, capability)
    case capability
    when :self_charge
      self.add_charge 1 if game.turn % 30 == 0
    when :ai
      Enemy.process(game, rng, self)
    end
  end
  
  def <<(message, time=-1)
    @pending_messages << [time, message]
    self
  end
  
  private
  
  def select_health(rng, range)
    if range.nil? then 10 else rng.rand(range[0]..range[1]) end
  end
  
  def select_item(game, rng, options, templates)
    return nil if options.nil?
    item = options[rng.rand(options.size)]
    fail "Cannot identify item: #{weapon}" if templates[item].nil?
    return Entity.new(game, rng, templates, templates[item])
  end
end