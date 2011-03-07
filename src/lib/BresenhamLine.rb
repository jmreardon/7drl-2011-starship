def get_line(x0,x1,y0,y1)
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
      points << [y, x]
    else
      points << [x, y]
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