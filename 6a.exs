input = """
Time:        44     70     70     80
Distance:   283   1134   1134   1491\
"""

lines = String.split(input, "\n")

[times, dists] =
  for line <- lines do
    for(
      word <- String.split(line, " "),
      Integer.parse(word) != :error,
      do: String.to_integer(word)
    )
  end

ans =
  for i <- 0..(length(times) - 1) do
    # x(time - x) > dist
    # x - time x + dist > 0
    # (time - sqrt(time^2 - 4 dist)) / 2 < x < (time + sqrt(time^2 + 4 dist)) / 2
    time = Enum.at(times, i)
    dist = Enum.at(dists, i)
    x1 = trunc((time - :math.sqrt(:math.pow(time, 2) - 4 * dist)) / 2 + 1)
    # IO.inspect([:math.pow(time, 2) - 4 * dist, :math.sqrt(:math.pow(time, 2) - 4 * dist), x1])
    time - 2 * x1 + 1
  end
  |> Enum.product()

IO.inspect(ans)
# 219849
