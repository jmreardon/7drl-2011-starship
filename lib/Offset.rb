module Offset
  def Offset.offset(loc, l, x, y)
    return [loc[0]+l,loc[1]+x,loc[2]+y]
  end
end