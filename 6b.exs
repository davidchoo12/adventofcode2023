input = """
Time:        44     70     70     80
Distance:   283   1134   1134   1491\
"""

lines = String.split(input, "\n")

[time, dist] =
  for line <- lines do
    for word <- String.split(line, " "), Integer.parse(word) != :error, reduce: "" do
      acc -> acc <> word
    end
    |> String.to_integer()
  end

# x(time - x) > dist
# x - time x + dist > 0
# (time - sqrt(time^2 - 4 dist)) / 2 < x < (time + sqrt(time^2 + 4 dist)) / 2
x1 = trunc((time - :math.sqrt(:math.pow(time, 2) - 4 * dist)) / 2 + 1)
ans = time - 2 * x1 + 1

IO.inspect(ans)
# 219849
