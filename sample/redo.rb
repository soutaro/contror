for x in 1...3
  redo if x == 2
end

[1,2,3].each do |x|
  redo if x == 2
end
