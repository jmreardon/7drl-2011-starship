
class MapBuilder
  
  def constructMap(rng)
    @rng = rng
    maxRoomDepth = 8 + rng.rand(2)
    roomDepth = [0,0,0,maxRoomDepth,0,0,0,0]
    levelLength = [0,0,0,200+5*rng.rand(10),0,0,0,0]
    levelStart = [0,0,0,-(levelLength[3]/2),0,0,0,0]
    for i in [4,5,6,7,2,1,0]
      roomDepth[i] = [3, roomDepth[nextToMiddle i] - 1 - rand(2)].max
      levelLength[i] = [60, levelLength[nextToMiddle i] - 5 * rand(10)].max
      
      minLevelStart = levelStart[nextToMiddle i]
      maxLevelStart = minLevelStart + (levelLength[nextToMiddle i] - levelLength[i])
      levelStart[i] = minLevelStart + (maxLevelStart == minLevelStart ? 0 : rng.rand(maxLevelStart - minLevelStart))
    end
    
    #normalize
    minStart = levelStart.min - 35
    levelStart = levelStart.map { |s| s - minStart }
    
    @turboliftLocs = ((levelStart[3]+5)...(levelLength[3]-5)).step(80).to_a
    diff = (levelLength[3] - @turboliftLocs[-1])/2
    @turboliftLocs.map!{|x| x + diff}
    
    @levelWidth = maxRoomDepth*2 + 5 + 2*3
    
    @gameMap = Array.new(8) do |x|
       Array.new(@levelWidth) do |y|   
        Array.new(levelLength.zip(levelStart).map{ |x,y| x + y }.max + 35, nil)
      end
    end
    
    @rooms = Array.new(8) do |x|
      Array.new()
    end
    
    for l in 0..7
      processLevel l, roomDepth[l], levelLength[l], levelStart[l]
      
    end
    
    return {:map => @gameMap, :rooms => @rooms, :width => @levelWidth}
  end
  
  private
  
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
  end
  
  private
  
  def carveRooms(level, section)
    x1 = section[0][0]
    y1 = section[0][1]
    x2 = section[1][0]
    y2 = section[1][1]
    
    bottom = y1 > @levelWidth/2
    if x2 - x1 > 50
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
    end
    
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
    bowLength = 5 + bowWidth/2 + @rng.rand(bowWidth/2)
    bowSplit = @rng.rand(2) == 1 && level != 3
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

    if bowSplit
      @rooms[level] << [[startX+(if flip then 1 else 0 end), @levelWidth/2 - bowWidth/2+1],[endX-(if flip then 0 else 1 end),@levelWidth/2-1]]
      @rooms[level] << [[startX+(if flip then 1 else 0 end), @levelWidth/2 + 1],[endX-(if flip then 0 else 1 end),@levelWidth/2 + bowWidth/2-1]]
    else
      @rooms[level] << [[startX+(if flip then 1 else 0 end), @levelWidth/2 - bowWidth/2+1],[endX-(if flip then 0 else 1 end),@levelWidth/2 + bowWidth/2-1]]
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