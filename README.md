# Benchmark Levenshtein
Levenshtein in D, but with a benchmark input for faster processing.

# Overview
This is a modification of the `levenshteinDistance` from the standard D library. It implements a benchmarking feature for the Levenshtein Distance that allows the end user to specify a value at which they want the comparison to return. This isn't my own idea. Full credit goes to [Markos Gaivo](https://github.com/samastur/markos.gaivo.net/blob/fa634b5d04c8f96d7b081e7fbd8bd1b467d0b888/articles/content/speeding-up-levenshtein.md), who originally posted on it. The specific implementation, however, is my own.

# License
Benchmark Levenshtein is distributed under the Boost Software License. See [LICENSE](https://github.com/calebjcourtney/benchmark_levenshtein/blob/master/LICENSE).

# Usage
This can be used in a similar manner as the original `levenshteinDistance` that is [included in the standard D library](https://github.com/dlang/phobos/blob/master/std/algorithm/comparison.d).
```d
// all from the standard library
assert(levenshteinDistance("cat", "rat") == 1);
assert(levenshteinDistance("parks", "spark") == 2);
assert(levenshteinDistance("abcde", "abcde") == 0);
assert(levenshteinDistance("abcde", "abCde") == 1);
assert(levenshteinDistance("kitten", "sitting") == 3);
assert(levenshteinDistance("ID", "I♥D") == 1);
```

In addition to the standard usage, this implementation includes the ability to use the `benchmark` input, allowing for failing faster. The question becomes "at what point should I stop calculating the edit distance?"
```d
assert(levenshteinDistance("Michigan", "Minnesota", 3) == 3);  // typically this would return 7
assert(levenshteinDistance("Fifteen", "Fourteen", 2) == 2);  // typically this would return 4
```

So, the purpose would be that perhaps you've already found a closer match, and you want to benchmark against that already existing match. Unless this match is closer, it will fail faster. The only time this process should be slower than the original implementation is if the given input and target are closer than the given benchmark, but more testing on that needs to be done.
