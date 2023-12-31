input = """
%cv -> xz
%kt -> qx, rz
%cb -> kt
%pl -> sf, db
%zd -> ln, gf
%bf -> qx, pf
%xz -> jd
%xm -> db
%vz -> cr, vc
%qq -> qm, gf
&xn -> th
%nn -> ff, db
%gx -> cd
&qn -> th
%qk -> vc
&xf -> th
%qj -> xm, db
%fn -> pr, gf
%sf -> bp
%jd -> qx, vm
%mc -> ds, db
%tj -> lc, gf
%jz -> qj, db
%sb -> ks, vc
%ln -> gf, qq
%bx -> qx, qp
broadcaster -> sr, ch, hd, bx
%ch -> db, mc
%ds -> cc
&qx -> cb, cv, bx, xz, vm, zl
%bp -> db, jz
&zl -> th
%vl -> gf, fj
&db -> ff, ds, sf, ch, cc, xf
&th -> rx
%cr -> gx, vc
%sr -> gf, vl
%lr -> sb
%hv -> lr
%cl -> qx, bf
%lc -> gf, fn
%pm -> vc, qk
%cc -> nn
%gm -> tj, gf
%vm -> cl
%ff -> pl
%qp -> cb, qx
%pf -> qx
&vc -> lr, hd, ks, qn, gx, nh, hv
%qm -> gm
%nh -> hv
%rz -> qx, cv
%ks -> vz
%fj -> zd
&gf -> fj, qm, xn, sr
%pr -> gf
%cd -> pm, vc
%hd -> vc, nh\
"""

lines = String.split(input, "\n")

# flipflop aka ff
# 1 -> % 0 (nothing happens)
# 1 -> % 1 (nothing happens)
# 0 -> % 0 -> 1 (% 1)
# 0 -> % 1 -> 0 (% 0)

# conjunction aka nand
# all 1s -> & -> 0
# any 0s -> & -> 1

# adjlist = %{name => [neighbour name]}
# nodes = %{name => %{type: %/&, state: 0/1 if %, %{input name => 0/1} if &}}

{adjlist, temp_nodes} =
  for line <- lines, reduce: {%{}, %{}} do
    {acc1, acc2} ->
      [name_temp, neighbours_str] = String.split(line, " -> ")

      {type, name} =
        case name_temp do
          "broadcaster" -> {name_temp, name_temp}
          _ -> String.split_at(name_temp, 1)
        end

      state =
        case type do
          # "%" -> 0
          "%" -> %{}
          "&" -> %{}
          _ -> :none
        end

      neighbours = String.split(neighbours_str, ", ")
      {Map.put(acc1, name, neighbours), Map.put(acc2, name, %{type: type, state: state})}
  end

conj_nodes =
  for {name, %{type: type}} <- temp_nodes, type == "&" do
    from_names = for {from_name, to_names} <- adjlist, name in to_names, do: from_name
    init_state = from_names |> Enum.map(&{&1, 0}) |> Enum.into(%{})
    {name, %{type: type, state: init_state}}
  end
  |> Enum.into(%{})

ff_nodes =
  for {name, %{type: type}} <- temp_nodes, type == "%" do
    from_names = for {from_name, to_names} <- adjlist, name in to_names, do: from_name
    init_state = from_names |> Enum.map(&{&1, 0}) |> Enum.into(%{})
    {name, %{type: type, state: Map.put(init_state, :on, 0)}}
  end
  |> Enum.into(%{})

nodes =
  Map.merge(temp_nodes, conj_nodes)
  |> Map.merge(ff_nodes)
  |> Map.merge(%{"rx" => %{type: "%", state: %{"th" => 1, on: 0}}})

# dbg([adjlist, nodes])

defmodule ButtonPresser do
  def process(_adjlist, nodes, queue, from_names_to_th) when length(queue) == 0 do
    {nodes, from_names_to_th}
  end

  # from_names_to_th = [from_name]
  def process(adjlist, nodes, queue, from_names_to_th) do
    [first | rest] = queue
    {from_name, signal, to_name} = first
    to_node = nodes[to_name]

    next_from_names_to_th =
      if to_name == "th" && signal == 1,
        do: [from_name | from_names_to_th],
        else: from_names_to_th

    if to_node == nil do
      process(adjlist, nodes, rest, next_from_names_to_th)
    else
      %{type: to_type, state: to_state} = to_node

      {new_to_state, outputs} =
        case {to_type, to_state, signal} do
          {"%", _, 1} ->
            new_to_state = Map.put(to_state, from_name, signal)
            {new_to_state, []}

          {"%", _, 0} ->
            out_signal = if to_state[:on] == 0, do: 1, else: 0
            new_to_state = Map.put(to_state, from_name, signal) |> Map.put(:on, out_signal)
            {new_to_state, Enum.map(adjlist[to_name] || [], &{to_name, out_signal, &1})}

          # {"%", _, 0} when to_state[:on] == 1 ->
          #   new_to_state = Map.put(to_state, from_name, signal) |> Map.put(:on, signal)
          #   {new_to_state, Enum.map(adjlist[to_name] || [], &{to_name, 0, &1})}

          {"&", _, _} ->
            new_to_state = Map.put(to_state, from_name, signal)

            {new_to_state,
             if(Map.values(new_to_state) |> Enum.all?(&(&1 == 1)),
               do: adjlist[to_name] |> Enum.map(&{to_name, 0, &1}),
               else: adjlist[to_name] |> Enum.map(&{to_name, 1, &1})
             )}
        end

      next_nodes = Map.put(nodes, to_name, Map.put(nodes[to_name], :state, new_to_state))
      process(adjlist, next_nodes, rest ++ outputs, next_from_names_to_th)
    end
  end
end

# queue = {from name, input 0/1, to name}
init_queue = adjlist["broadcaster"] |> Enum.map(&{"broadcaster", 0, &1})

{_nodes, from_names_to_th_indexes} =
  Enum.reduce_while(
    1..5000,
    {nodes, %{}},
    # from_names_to_th_indexes = %{from_name => i}
    fn i, {nodes, from_names_to_th_indexes} ->
      {new_nodes, new_from_names_to_th} =
        ButtonPresser.process(adjlist, nodes, init_queue, [])

      new_from_names_to_th_indexes =
        new_from_names_to_th
        |> Enum.reduce(from_names_to_th_indexes, fn new_from_name, acc ->
          Map.put_new(acc, new_from_name, i)
        end)

      if Map.keys(new_from_names_to_th_indexes) == Map.keys(new_nodes["th"][:state]) do
        {:halt, {new_nodes, new_from_names_to_th_indexes}}
      else
        {:cont, {new_nodes, new_from_names_to_th_indexes}}
      end
    end
  )

# elixir standard library cannot do LCM
# src https://programming-idioms.org/idiom/75/compute-lcm/983/elixir
defmodule BasicMath do
  def gcd(a, 0), do: a
  def gcd(0, b), do: b
  def gcd(a, b), do: gcd(b, rem(a, b))

  def lcm(0, 0), do: 0
  def lcm(a, b), do: div(a * b, gcd(a, b))
end

ans =
  from_names_to_th_indexes |> Map.values() |> Enum.reduce(fn n, acc -> BasicMath.lcm(acc, n) end)

dbg(ans)
# 224046542165867

# this solution is a specific solution for the input
# had the idea to visualize the graph using mermaid js to see what change on each button press, but mermaid js has poor layout for this many nodes
# found graphviz which provides better layout thanks to reddit and got the hint that it's a binary counter
# generated graphs using https://dreampuf.github.io/GraphvizOnline/ with the output of below
# graphs files are named by the no of button presses
# observed the pattern is as follows:
# 4 of (12 % nodes chained -> 1 & node -> 1 & node) -> 1 & node -> rx
# so to trigger rx, the last & node needs to send 0, which means it needs to receive 1 from all 4 blocks at the same time
# for each block to send 1, the % nodes that needs to send 1 to the & node
# each button press will make the % nodes form the binary representation of the number of presses
# so we can deduce when each of the 4 blocks will send 1 to the & nodes
# vc: 111011010001 = 3793
# db: 111101010011 = 3923
# qx: 111010011011 = 3739
# gf: 111110111011 = 4027
# so to get all 4 blocks to send 1 at the same time, find the LCM of the 4 integers

# very nice visualization https://www.reddit.com/r/adventofcode/comments/18mypla/2023_day_20_input_data_plot/

# viz = fn nodes ->
#   IO.puts("digraph G {")

#   edge_list_str =
#     for {node, neighbours} <- adjlist do
#       for n <- neighbours do
#         signal = Integer.to_string(nodes[n][:state][node])

#         state1 =
#           if nodes[node][:type] == "%", do: Integer.to_string(nodes[node][:state][:on]), else: ""

#         state2 = if nodes[n][:type] == "%", do: Integer.to_string(nodes[n][:state][:on]), else: ""

#         # mermaid js syntax
#         # ~s(#{nodes[node][:type]}#{node}#{state1} -- #{signal} --> #{nodes[n][:type]}#{n}#{state2})

#         # graphviz syntax
#         ~s("\\#{nodes[node][:type]} #{node} #{state1}" -> "\\#{nodes[n][:type]} #{n} #{state2}" [label=#{signal}];)
#       end
#     end
#     |> Enum.flat_map(& &1)
#     |> Enum.join("\n")

#   IO.puts(edge_list_str)
#   IO.puts("}")
# end

# viz.(nodes)
