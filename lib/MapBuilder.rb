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

require_relative "Offset"

include Offset

class MapBuilder
  
  def constructMap(game, rng, roomTemplates, objectTemplates)
    @rng = rng
    @game = game
    @objects = []
    @objectTemplates = objectTemplates
    maxRoomDepth = 5 + rng.rand(2)
    roomDepth = [0,0,0,0,maxRoomDepth,0,0,0]
    levelLength = [0,0,0,0,120+5*rng.rand(10),0,0,0]
    levelStart = [0,0,0,0-(levelLength[3]/2),0,0,0]
    for i in [3,5,6,7,2,1,0]
      roomDepth[i] = [3, roomDepth[nextToMiddle i] - 1 - rand(1)].max
      levelLength[i] = [40, levelLength[nextToMiddle i] - 5 * rand(10)].max
      
      minLevelStart = levelStart[nextToMiddle i]
      maxLevelStart = minLevelStart + (levelLength[nextToMiddle i] - levelLength[i])
      levelStart[i] = minLevelStart + (maxLevelStart == minLevelStart ? 0 : rng.rand(maxLevelStart - minLevelStart))
    end
    
    #normalize
    minStart = levelStart.min - 35
    levelStart = levelStart.map { |s| s - minStart }
    
    @turboliftLocs = ((levelStart[4]+5)...(levelLength[4]-5)).step(30).to_a
    diff = (levelLength[4] - @turboliftLocs[-1])/2
    @turboliftLocs.map!{|x| x + diff}
    
    @levelWidth = maxRoomDepth*2 + 5 + 2*3
    
    @gameMap = Array.new(8) do |x|
       Array.new(@levelWidth) do |y|   
        Array.new(levelLength.zip(levelStart).map{ |x,y| x + y }.max + 35, nil)
      end
    end
    
    @rooms = Array.new(8) do |x|
      Hash.new()
    end
    
    levelsSuccess = (0..7).all?{ |l| processLevel l, roomDepth[l], levelLength[l], levelStart[l] }
    return false unless levelsSuccess
    
    processRooms roomTemplates
    return {:map => @gameMap, :objects => @objects, :rooms => @rooms, :width => @levelWidth, :length => levelLength.zip(levelStart).map{ |x,y| x + y }.max + 35}
  end
  
  private
  
  def processRooms(roomTemplates)
    random, counted = roomTemplates.partition{ |k,v| v[:count] < 1}
    #work out the specific rooms
    counted.each do |name, spec|
      # TODO this should be using the rng
      levels = spec[:levels].shuffle
      levels.find do |l|
        fail "#{name}: #{spec}" if l > 7
        candidates = @rooms[l].select{|k,v| specs_match? v, spec}
        unless candidates.empty?
          processRoom l, *candidates.to_a.shuffle.first, name, spec
          true
        else
          false
        end
      end
    end
    
    #place the rest
    (0...8).each do |l|
      templatesLevel = random.select{ |name,spec| spec[:levels].include?(l) }
      fail "No templates for level #{l}" if templatesLevel.empty?
      @rooms[l].select{|l,d| d[:name].nil?}.each do |loc, data|
        templates = templatesLevel.select{|kname,spec| specs_match? data, spec}
        fail "no templates for room #{loc}, #{data}" if templates.empty?
        odds = templates.map{|t| [t[1][:count], t]}.inject([[0, nil]]){ |memo,obj| memo.push([memo[-1][0]+obj[0], obj[1]])}
        value = @rng.rand(odds.last.first+0.00001)
        target = odds.find{ |v,t| value < v}
        processRoom l, loc, data, *target[1]
      end
    end
  end
  
  def processRoom(level, roomLoc, roomData, name, spec)
    roomData[:name] = name
    if spec[:crawl]
      insertCrawlAccess level, ((roomLoc[0]+roomLoc[2])/2), roomLoc[1], roomLoc[3]
    end
    candidates = Hash[(roomLoc[0]..roomLoc[2]).to_a.product((roomLoc[1]..roomLoc[3]).to_a).select{|x| doors_at(level, x) == 0 }.map{ |x| [x, true] }]
    if spec[:objects]
      (spec[:objects]).each do |chance, kind|
        candidates.delete(placeObject kind, level, candidates) if @rng.rand(1.0) < chance
      end
    end
  end
  
  def placeObject(kind, level, candidates)
    the_kind = if kind.kind_of?(Array) then kind[@rng.rand(kind.size)] else kind end
    obj = Entity.new(@game, @rng, @objectTemplates, @objectTemplates[the_kind])
    locs = candidates.to_a
    if obj.capabilities.include?(:against_wall)
      locs = locs.select{ |x,t| walls_at(level, x) > 2 }
    elsif obj.capabilities.include?(:away_wall)
      locs = locs.select{ |x,t| walls_at(level, x) == 0 }
    end
    return nil if locs.size == 0
    
    target = locs[@rng.rand(locs.size)]
    fail "Target was nil" if target.nil?
    @objects << [obj, [level, target[0][0], target[0][1]]]
    target[0]
  end

  def walls_at(level, loc)
    SURROUNDING.map{|l,x,y| Offset.offset([level].concat(loc),l,x,y)}.
      map{ |l,x,y| if @gameMap[l] && @gameMap[l][y] && @gameMap[l][y][x] == :wall then 1 else 0 end}.reduce(:+)
  end
  
  def doors_at(level, loc)
    SURROUNDING.map{|l,x,y| Offset.offset([level].
      concat(loc),l,x,y)}.
      map{ |l,x,y| if @gameMap[l] && @gameMap[l][y] && [:door, :hatch].include?(@gameMap[l][y][x]) then 1 else 0 end}.reduce(:+)
  end
  
  def insertCrawlAccess(level, x, y1, y2)
    mid = @levelWidth/2
    return if y1 == mid+1 || y2 == mid-1
    if y1 > mid && y2 > mid
      @gameMap[level][y2+1][x] = :hatch
    elsif y1 < mid && y2 < mid
      @gameMap[level][y1-1][x] = :hatch
    end
    #otherwise we have an end room, and we don't care
  end
  
  def specs_match?(candidate, spec)
    return false if candidate.has_key? :name
    return true unless spec[:prereqs]
    spec[:prereqs].all?{ |k,v| candidate[k] == v}
  end
  
  def processLevel(level, roomDepth, levelLength, levelStart)
    # construct hallway and skeletal walls
    for x in levelStart...(levelStart + levelLength)
      #exterior room and hall walls
      for y in [roomDepth+3, -(roomDepth+3), 2, -2].map{ |x|@levelWidth/2 + x }
       @gameMap[level][y][x] = :wall
      end
      #hall
      for y in [1,0,-1].map{ |x|@levelWidth/2 + x }
       @gameMap[level][y][x] = :floor
      end
    end  

    exteriorLocs = [roomDepth+5, -(roomDepth+5)].map{ |x|@levelWidth/2 + x }
    levelLifts = @turboliftLocs.select{ |x| ((levelStart+5)..(levelStart + levelLength-5)).member?(x) }
    return false if levelLifts.empty?
    levelLifts.each do |loc|
      @gameMap[level][@levelWidth/2 + 1][loc] = @gameMap[level][@levelWidth/2 - 1][loc] = :lift
      for i in [loc+1, loc+2, loc-1, loc-2]
        @gameMap[level][@levelWidth/2 + 1][i] = @gameMap[level][@levelWidth/2 - 1][i] = :wall
      end
      #walls behind lifts
      for y in exteriorLocs[1]..exteriorLocs[0]
        if y > @levelWidth/2 + 2 or y < @levelWidth/2 - 2
          @gameMap[level][y][loc] = @gameMap[level][y][loc-1] = @gameMap[level][y][loc+1] = :wall
        end
      end
    end
    
    #end of hall walls
    for y in exteriorLocs[1]..exteriorLocs[0]
      @gameMap[level][y][levelStart-1] = @gameMap[level][y][levelStart+levelLength] = 
        @gameMap[level][y][levelStart-3] = @gameMap[level][y][levelStart+levelLength+2] = :wall
      @gameMap[level][y][levelStart-2] = @gameMap[level][y][levelStart+levelLength+1] = :floor
    end
    
    #exterior hull walls
    for x in (levelStart-2)...(levelStart + levelLength + 2)
       for y in exteriorLocs
         @gameMap[level][y][x] = :wall
        end
        for y in [roomDepth+4, -(roomDepth+4)].map{ |x|@levelWidth/2 + x }
         @gameMap[level][y][x] = :floor
        end
    end

    endSection(level, levelStart, levelLength, roomDepth, levelStart + levelLength+1, levelStart + levelLength + 2, levelStart + levelLength, false)
    endSection(level, levelStart, levelLength, roomDepth, levelStart -1, levelStart-2, levelStart-1, true)
    
    sections = Array.new()
    sectionStartsX = [levelStart] + levelLifts.map{|x| x + 2};
    sectionEndsX = levelLifts.map{|x| x - 2} + [levelStart+levelLength-1]
    sections += sectionStartsX.zip(sectionEndsX).map{|x1,x2| [[x1, @levelWidth/2 - (roomDepth+2)],[x2, @levelWidth/2 - 3]]}
    sections += sectionStartsX.zip(sectionEndsX).map{|x1,x2| [[x1, @levelWidth/2 + 3],[x2, @levelWidth/2 + (roomDepth+2)]]}
    sections.each{|s| carveRooms(level, s)}
    true
  end
  
  private
  
  def carveRooms(level, section)
    x1 = section[0][0]
    y1 = section[0][1]
    x2 = section[1][0]
    y2 = section[1][1]
    
    bottom = y1 > @levelWidth/2
    if x2 - x1 > 25
      midpoint = @rng.rand(10)+(x1+x2)/2-5
      carveCrawlspace(level, midpoint, y1, y2)
      carveRooms(level, [[x1,y1], [midpoint-2, y2]])
      carveRooms(level, [[midpoint+2,y1], [x2, y2]])
      return
    end
    
    if x2-x1 > (y2-y1)*2+3 and @rng.rand(100) > (x1-x2)
      midpoint = [[x1+4, @rng.rand((x2-x1)/5)+(x1+x2)/2].max, x2-4].min
      for y in y1..y2
        @gameMap[level][y][midpoint] = :wall
      end
      carveRooms(level, [[x1,y1], [midpoint-1, y2]])
      carveRooms(level, [[midpoint+1,y1], [x2, y2]])
    else
      @gameMap[level][if bottom then y1-1 else y2+1 end][x1+(x2-x1)/2] = :door
      carveRoom(level,x1,y1,x2,y2)
    end
    
  end
  
  def carveRoom(level,x1,y1,x2,y2)
    for x in x1..x2
      for y in y1..y2
       @gameMap[level][y][x] = :floor
      end
    end
    roomSpec = Hash.new
    size = ((x1-x2+1)*(y1-y2+1)).abs
    if size >= 60
      roomSpec[:large] = true
    elsif size >= 22
      roomSpec[:medium] = true
    else
      roomSpec[:small] = true
    end
    roomSpec[:number] = @rooms[level].size+1
    @rooms[level][[x1,y1,x2,y2]] = roomSpec
  end
  
  def carveCrawlspace(level, x, y1, y2)
    for y in y1..y2
      @gameMap[level][y][x] = :floor
      @gameMap[level][y][x-1] = @gameMap[level][y][x+1] = :wall
    end
    @gameMap[level][y1-1][x] = :hatch
    @gameMap[level][y2+1][x] = :hatch
  end
  
  def endSection(level, levelStart, levelLength, roomDepth, startX, endX, doorX, flip)
    bowWidth = [5 + roomDepth + @rng.rand(roomDepth), 20].min
    bowLength = bowWidth/2 + @rng.rand(bowWidth/2)
    bowSplit = @rng.rand(2) == 1 && level != 4
    if flip
      startX-=bowLength
    else
      endX+=bowLength
    end
    wallX = if flip then startX else endX end
    hatchX = if !flip then startX else endX end
   
    for x in startX..(endX)
      for y in [@levelWidth/2 - bowWidth/2, @levelWidth/2 + bowWidth/2]
        @gameMap[level][y][x] = if x == hatchX then :hatch else :wall end
      end
      for y in (@levelWidth/2 - bowWidth/2 + 1)...(@levelWidth/2 + bowWidth/2)
        @gameMap[level][y][x] = if x == wallX then :wall else :floor end
      end
      if bowSplit
        @gameMap[level][@levelWidth/2][x] = :wall
      end
    end
    
    for i in (if bowSplit then [@levelWidth/2-1, @levelWidth/2+1] else [@levelWidth/2] end)
      @gameMap[level][i][doorX] = :door
    end
    
    roomSpec = Hash.new
    size = if bowSplit
      bowWidth*bowLength/2-bowLength
    else 
      bowWidth*bowLength
    end
    size = size.abs
    
    if size >= 60
      roomSpec[:large] = true
    elsif size >= 30
      roomSpec[:medium] = true
    else
      roomSpec[:small] = true
    end
    roomSpec[:number] = @rooms[level].size+1

    if bowSplit
      @rooms[level][[startX+(if flip then 1 else 0 end), @levelWidth/2 - bowWidth/2+1,endX-(if flip then 0 else 1 end),@levelWidth/2-1]] = roomSpec.merge({:end => true})
      @rooms[level][[startX+(if flip then 1 else 0 end), @levelWidth/2 + 1,endX-(if flip then 0 else 1 end),@levelWidth/2 + bowWidth/2-1]] = roomSpec.merge({:end => true})
    else
      roomData = if level == 4 && !flip then {:bridge => true} else {:end => true} end
      @rooms[level][[startX+(if flip then 1 else 0 end), @levelWidth/2 - bowWidth/2+1,endX-(if flip then 0 else 1 end),@levelWidth/2 + bowWidth/2-1]] = roomSpec.merge(roomData)
    end
    
  end
  
  
  def nextToMiddle(level)
    if level > 3
      level - 1
    else
      level + 1
    end
  end
  
end
