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

# Originally copied from http://roguebasin.roguelikedevelopment.org/index.php?title=Bresenham%27s_Line_Algorithm

module BresenhamLine

  def lineBetween(src, dest) 
    fail "Coords on different levels" unless src[0] == dest[0]
    return get_line(src[1],dest[1],src[2],dest[2],src[0])
  end
  
  private
  
  def get_line(x0,x1,y0,y1,level)
    points = []
    steep = ((y1-y0).abs) > ((x1-x0).abs)
    reversed = false
    if steep
      x0,y0 = y0,x0
      x1,y1 = y1,x1
    end
    if x0 > x1
      x0,x1 = x1,x0
      y0,y1 = y1,y0
      reversed = true
    end
    deltax = x1-x0
    deltay = (y1-y0).abs
    error = (deltax / 2).to_i
    y = y0
    ystep = nil
    if y0 < y1
      ystep = 1
    else
      ystep = -1
    end
    for x in x0..x1
      if steep
        points << [level, y, x]
      else
        points << [level, x, y]
      end
      error -= deltay
      if error < 0
        y += ystep
        error += deltax
      end
    end
    if reversed
      points.reverse!
    end
    return points
  end

end