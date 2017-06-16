import "/futlib/math"
import "/futlib/monoid"

module type sobol_dir = {
  val n: i32
  val a: [n]u32
  val s: [n]i32
  val m: [n][]u32
}

module type sobol = {
  val D : i32                              -- dimensionality of sequence
  val norm : f64                           -- the value 2**32
  val independent : i32 -> [D]u32          -- [independent i] returns the i'th
                                           -- sobol vector (in u32)
  val recurrent : i32 -> [D]u32 -> [D]u32  -- [recurrent i v] returns the i'th
                                           -- sobol vector given v is the
                                           -- (i-1)'th sobol vector
  val chunk : i32 -> (n:i32) -> [n][D]f64  -- [chunk i n] returns the array
                                           -- [v_i,...,v_(i+n-1)] of sobol
                                           -- vectors where v_j is the j'th
                                           -- D-dimensional sobol vector
  module Reduce :
      (X : { include monoid
             val f : [D]f64 -> t }) -> { val run : i32 -> X.t }
}

module Sobol (D: sobol_dir) (X: { val D : i32 }) : sobol = {
  let D = X.D

  -- Compute direction vectors. In general, some work can be saved if
  -- we know the number of sobol numbers (N) up front. Here, however,
  -- we calculate sufficiently sized direction vectors to work with
  -- upto N = 2^L, where L=32 (i.e., the maximum number of bits
  -- needed).

  let L = 32i32

  -- direction vector for dimension j
  let dirvec (j:i32) : [L]u32 = unsafe
    if j == 0 then
       map (\i -> 1u32 << (32u32-u32(i+1))
           ) (iota L)
    else
       let s = D.s[j-1]
       let a = D.a[j-1]
       let V = map (\i -> if i >= s then 0u32
                          else D.m[j-1,i] << (32u32-u32(i+1))
                   ) (iota L)
       loop ((i,V) = (s, V)) =
         while i < L do
           let v = V[i-s]
           let vi0 = v ^ (v >> (u32(s)))
           let vi =
             loop ((k,vi) = (1,vi0)) = while k <= s-1 do
                  (k+1, vi ^ (((a >> u32(s-1-k)) & 1u32) * V[i-k]))
             in vi
           in (i+1, V with [i] <- vi)
       in V

  let index_of_least_significant_0 (x:i32) : i32 =
    loop (i = 0) =
      while i < 32 && ((x>>i)&1) != 0 do i + 1
    in i

  let norm = 2.0 f64.** 32.0

  let grayCode (x: i32): i32 = (x >> 1) ^ x

  let testBit (n: i32) (ind:i32) : bool =
    let t = (1 << ind) in (n & t) == t

  let dirvecs : [D][L]u32 =
    map dirvec (iota D)

  let recSob (i:i32) (dirvec:[L]u32) (x:u32) : u32 =
    unsafe if i == 0 then 0u32
           else x ^ dirvec[index_of_least_significant_0 (i-1)]

  let recurrent (i:i32) (xs:[D]u32) : [D]u32 =
    map (recSob i) dirvecs xs

  let indSob (n:i32) (dirvec:[L]u32) : u32 =
    let reldv_vals = map (\dv i -> if testBit (grayCode n) i then dv
                                   else 0u32)
                         dirvec (iota L)
    in reduce (^) 0u32 reldv_vals

  let independent (i:i32) : [D]u32 =
    map (indSob i) dirvecs

  -- utils
  let recM (i:i32) : [D]u32 =
    let bit = index_of_least_significant_0 i
    in map (\row -> unsafe row[bit]) dirvecs

  -- computes sobol numbers: offs,..,offs+chunk-1
  let chunk (offs:i32) (n:i32) : [n][D]f64 =
    let sob_beg = independent offs
    let contrbs = map (\(k:i32): [D]u32  ->
                       if k==0 then sob_beg
                       else recM (k+offs-1))
                    (iota n)
    let vct_ints = scan (\x y -> map (^) x y) (replicate D 0u32) contrbs
    in map (\xs -> map (\x -> f64(x)/norm) xs) vct_ints

  module Reduce (X : { include monoid
                       val f : [D]f64 -> t }) : { val run : i32 -> X.t } =
  {
    -- let run (N:i32) : X.t =
    --   stream_red_per X.op (\ [sz] (ns:[sz]i32) : X.t ->
    --                       reduce X.op X.ne (map X.f (chunk ns[0] sz)))
    --    (iota N)

    let run (N:i32) : X.t =
      let vs = stream_map (\ [sz] (ns: [sz]i32): [sz][D]f64  ->
                           chunk ns[0] sz)
                          (iota N)
      let fs = map X.f vs
      in reduce X.op X.ne fs
  }
}
