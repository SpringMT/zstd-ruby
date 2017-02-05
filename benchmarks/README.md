# sample data
FROM http://www.cl.ecei.tohoku.ac.jp/~matsuda/LRE_corpus/

# usage


```
bundle exec ruby compress.rb city
```


# Result
## Compression

### Performance

```
% bundle exec ruby compress.rb city.json
Warming up --------------------------------------
              snappy    18.000  i/100ms
                gzip     2.000  i/100ms
                  xz     1.000  i/100ms
                 lz4    24.000  i/100ms
                zstd    17.000  i/100ms
Calculating -------------------------------------
              snappy    189.588  (±16.9%) i/s -    918.000  in   5.072385s
                gzip     27.703  (± 7.2%) i/s -    138.000  in   5.032686s
                  xz      1.621  (± 0.0%) i/s -      9.000  in   5.560271s
                 lz4    282.316  (±14.5%) i/s -      1.368k in   5.008697s
                zstd    195.722  (±14.3%) i/s -    952.000  in   5.027488s
```



### Data Size

#### before

```
% ls -alh samples/city.json
-rw-r--r--@ 1 makoto  staff   1.7M  2  5 16:07 samples/city.json
```

#### after

```
% ls -alh results
total 2712
-rw-r--r--   1 makoto  staff   219K  2  5 16:08 city.json.gzip
-rw-r--r--   1 makoto  staff   365K  2  5 16:08 city.json.lz4
-rw-r--r--   1 makoto  staff   358K  2  5 16:08 city.json.snappy
-rw-r--r--   1 makoto  staff   166K  2  5 16:08 city.json.xz
-rw-r--r--   1 makoto  staff   238K  2  5 16:08 city.json.zstd
```

## Decompression
### Performance

```
Warming up --------------------------------------
              snappy    59.000  i/100ms
                gzip    19.000  i/100ms
                  xz     5.000  i/100ms
                 lz4    51.000  i/100ms
                zstd    31.000  i/100ms
Calculating -------------------------------------
              snappy    583.211  (± 9.1%) i/s -      2.891k in   5.002226s
                gzip    195.468  (±10.7%) i/s -    969.000  in   5.028082s
                  xz     53.501  (± 7.5%) i/s -    270.000  in   5.083982s
                 lz4    511.275  (± 9.4%) i/s -      2.550k in   5.036539s
                zstd    302.455  (±16.5%) i/s -      1.488k in   5.070354s
```


