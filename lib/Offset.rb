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

module Offset
  SURROUNDING = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[0,1,1],[0,-1,-1],[0,-1,1],[0,1,-1]]
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  SURROUNDING_3D = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[0,1,1],[0,-1,-1],[0,-1,1],[0,1,-1],[1,0,0],[-1,0,0]]
  
  def Offset.offset(loc, l, x, y)
    [loc[0]+l,loc[1]+x,loc[2]+y]
  end

  def diff(l1,x1,y1,l2,x2,y2)
    [l2-l1, x2-x1, y2-y1]
  end
  
  def dist(l1,x1,y1,l2,x2,y2)
    ((l1-l2)**2 + (x1-x2)**2 + (y1-y2)**2)**0.5
  end
  
  def dist_sq(l1,x1,y1,l2,x2,y2)
    ((l1-l2)**2 + (x1-x2)**2 + (y1-y2)**2)
  end
end