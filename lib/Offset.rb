module Offset
  SURROUNDING = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[0,1,1],[0,-1,-1],[0,-1,1],[0,1,-1]]
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  SURROUNDING_3D = SURROUNDING.concat([[1,0,0], [-1,0,0]])
  def Offset.offset(loc, l, x, y)
    return [loc[0]+l,loc[1]+x,loc[2]+y]
  end
end