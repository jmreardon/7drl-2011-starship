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

require_relative "Entity"

class EnemyAI < Entity
  def initialize(game, rng, templates)
    super(game, rng, templates, :symbol => ['@', 4], :name => "Enemy Controller", :kind => :player, :mobile => false, :description => "The enemy AI")
  end
  
  def process(game, rng)
    messages = read_messages game
  end
end