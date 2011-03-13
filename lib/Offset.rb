module Offset
  SURROUNDING = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[0,1,1],[0,-1,-1],[0,-1,1],[0,1,-1]]
  AROUND = [[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
  SURROUNDING_3D = SURROUNDING.concat([[1,0,0], [-1,0,0]])
  
  def Offset.offset(loc, l, x, y)
    return [loc[0]+l,loc[1]+x,loc[2]+y]
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