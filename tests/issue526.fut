-- Issue with aliasing analysis that failed to produce enough values.
-- Crashed in fusion, but that wasn't where the problem actually was.

let main (t_v1: [][]i32) =
  let t_v4 = loop t_v2 = t_v1 for _i < 100 do rearrange (1,0) t_v2
  let y = map1 (\x -> t_v1[x]) (iota (length t_v1))
  let t_v9 = map2 (map2 (==)) t_v4 y
  in t_v9
