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
          "%" -> 0
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

nodes = Map.merge(temp_nodes, conj_nodes)
# dbg([adjlist, nodes])

defmodule ButtonPresser do
  def process(_adjlist, nodes, queue, high_count, low_count) when length(queue) == 0 do
    {nodes, high_count, low_count}
  end

  def process(adjlist, nodes, queue, high_count, low_count) do
    # dbg(queue)
    [first | rest] = queue
    {from_name, signal, to_name} = first
    new_high_count = if signal == 1, do: high_count + 1, else: high_count
    new_low_count = if signal == 0, do: low_count + 1, else: low_count
    to_node = nodes[to_name]

    if to_node == nil do
      process(adjlist, nodes, rest, new_high_count, new_low_count)
    else
      %{type: to_type, state: to_state} = to_node

      {new_to_state, outputs} =
        case {to_type, to_state, signal} do
          {"%", _, 1} ->
            {to_state, []}

          {"%", 0, 0} ->
            {1, Enum.map(adjlist[to_name], &{to_name, 1, &1})}

          {"%", 1, 0} ->
            {0, Enum.map(adjlist[to_name], &{to_name, 0, &1})}

          {"&", _, _} ->
            new_to_state = Map.put(to_state, from_name, signal)

            {new_to_state,
             if(Map.values(new_to_state) |> Enum.all?(&(&1 == 1)),
               do: adjlist[to_name] |> Enum.map(&{to_name, 0, &1}),
               else: adjlist[to_name] |> Enum.map(&{to_name, 1, &1})
             )}
        end

      next_nodes = Map.put(nodes, to_name, Map.put(nodes[to_name], :state, new_to_state))
      process(adjlist, next_nodes, rest ++ outputs, new_high_count, new_low_count)
    end
  end
end

# queue = {from name, input 0/1, to name}
init_queue = adjlist["broadcaster"] |> Enum.map(&{"broadcaster", 0, &1})

{final_nodes, final_high_count, final_low_count} =
  for _ <- 1..1000, reduce: {nodes, 0, 0} do
    {nodes, high_count, low_count} ->
      {new_nodes, new_high_count, new_low_count} =
        ButtonPresser.process(adjlist, nodes, init_queue, high_count, 1 + low_count)

      {new_nodes, new_high_count, new_low_count}
  end

ans = final_high_count * final_low_count
dbg(ans)
dbg(final_nodes)
