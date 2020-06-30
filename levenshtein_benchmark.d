module levenshtein.benchmark;

// full library
import std.range;

// specific imports
import std.conv: to;
import std.functional: binaryFun;
import std.algorithm.mutation : reverse;
import core.checkedint : mulu;
import core.exception : onOutOfMemoryError;
import core.stdc.stdlib : realloc;
import core.stdc.stdlib : free;

enum EditOp : char
{
    /** Current items are equal; no editing is necessary. */
    none = 'n',
    /** Substitute current item in target with current item in source. */
    substitute = 's',
    /** Insert current item from the source into the target. */
    insert = 'i',
    /** Remove current item from the target. */
    remove = 'r'
}


private struct Levenshtein(Range, alias equals, CostType = size_t)
{
    EditOp[] path()
    {
        EditOp[] result;
        size_t i = rows - 1, j = cols - 1;
        // restore the path
        while (i || j)
        {
            auto cIns = j == 0 ? CostType.max : matrix(i,j - 1);
            auto cDel = i == 0 ? CostType.max : matrix(i - 1,j);
            auto cSub = i == 0 || j == 0
                ? CostType.max
                : matrix(i - 1,j - 1);
            switch (min_index(cSub, cIns, cDel))
            {
            case 0:
                result ~= matrix(i - 1,j - 1) == matrix(i,j)
                    ? EditOp.none
                    : EditOp.substitute;
                --i;
                --j;
                break;
            case 1:
                result ~= EditOp.insert;
                --j;
                break;
            default:
                result ~= EditOp.remove;
                --i;
                break;
            }
        }
        reverse(result);
        return result;
    }

    ~this() {
        FreeMatrix();
    }

private:
    CostType _deletionIncrement = 1,
        _insertionIncrement = 1,
        _substitutionIncrement = 1;
    CostType[] _matrix;
    size_t rows, cols;

    // Treat _matrix as a rectangular array
    ref CostType matrix(size_t row, size_t col) { return _matrix[row * cols + col]; }

    void AllocMatrix(size_t r, size_t c) @trusted {
        bool overflow;
        const rc = mulu(r, c, overflow);
        assert(!overflow, "Overflow during multiplication to determine number "
                ~ " of matrix elements");
        rows = r;
        cols = c;
        if (_matrix.length < rc)
        {
            const nbytes = mulu(rc, _matrix[0].sizeof, overflow);
            assert(!overflow, "Overflow during multiplication to determine "
                ~ " number of bytes of matrix");
            auto m = cast(CostType *) realloc(_matrix.ptr, nbytes);
            if (!m)
                onOutOfMemoryError();
            _matrix = m[0 .. r * c];
            InitMatrix();
        }
    }

    void FreeMatrix() @trusted {
        free(_matrix.ptr);
        _matrix = null;
    }

    void InitMatrix() {
        foreach (r; 0 .. rows)
            matrix(r,0) = r * _deletionIncrement;
        foreach (c; 0 .. cols)
            matrix(0,c) = c * _insertionIncrement;
    }

    static uint min_index(CostType i0, CostType i1, CostType i2)
    {
        if (i0 <= i1)
        {
            return i0 <= i2 ? 0 : 2;
        }
        else
        {
            return i1 <= i2 ? 1 : 2;
        }
    }

    CostType distanceLowMem(Range s, Range t, CostType slen, CostType tlen, int benchmark = 10000)
    {
        CostType lastdiag, olddiag;
        AllocMatrix(slen + 1, 1);
        foreach (y; 1 .. slen + 1)
        {
            _matrix[y] = y;
        }
        foreach (x; 1 .. tlen + 1)
        {
            auto tfront = t.front;
            auto ss = s.save;
            _matrix[0] = x;
            lastdiag = x - 1;
            foreach (y; 1 .. rows)
            {
                olddiag = _matrix[y];
                auto cSub = lastdiag + (equals(ss.front, tfront) ? 0 : _substitutionIncrement);
                ss.popFront();
                auto cIns = _matrix[y - 1] + _insertionIncrement;
                auto cDel = _matrix[y] + _deletionIncrement;
                switch (min_index(cSub, cIns, cDel))
                {
                case 0:
                    _matrix[y] = cSub;
                    break;
                case 1:
                    _matrix[y] = cIns;
                    break;
                default:
                    _matrix[y] = cDel;
                    break;
                }
                lastdiag = olddiag;

                if (_matrix[y] >= benchmark)
                    return _matrix[y] + (tlen - slen).to!int;
            }
            t.popFront();
        }
        return _matrix[slen];
    }
}


/**
Returns the $(HTTP wikipedia.org/wiki/Levenshtein_distance, Levenshtein
distance) between `s` and `t`. The Levenshtein distance computes
the minimal amount of edit operations necessary to transform `s`
into `t`.  Performs $(BIGOH s.length * t.length) evaluations of $(D
equals) and occupies $(BIGOH min(s.length, t.length)) storage.
Params:
    equals = The binary predicate to compare the elements of the two ranges.
    s = The original range.
    t = The transformation target
Returns:
    The minimal number of edits to transform s into t.
Does not allocate GC memory.
*/
size_t levenshteinDistance(Range1, Range2)
    (Range1 s, Range2 t, int benchmark)
if (isForwardRange!(Range1) && isForwardRange!(Range2))
{
    auto slen = walkLength(s.save);
    auto tlen = walkLength(t.save);

    if (slen > tlen)
    {
        auto c = s;
        s = t;
        t = c;
    }

    // if the difference in lengths are greater than the benchmark,
    // then we can just return the difference in lengths
    if (benchmark < tlen - slen)
        return (tlen - slen);
    // otherwise, let's subtract the *known* needed edit distance
    // from the benchmark
    else
        benchmark -= (tlen - slen);

    alias eq = (a,b) => a == b;

    for (;;)
    {
        if (s.empty) return t.walkLength;
        if (t.empty) return s.walkLength;
        if (eq(s.front, t.front))
        {
            s.popFront();
            t.popFront();
            continue;
        }
        static if (isBidirectionalRange!(Range1) && isBidirectionalRange!(Range2))
        {
            if (eq(s.back, t.back))
            {
                s.popBack();
                t.popBack();
                continue;
            }
        }
        break;
    }

    slen = walkLength(s.save);
    tlen = walkLength(t.save);

    if (slen == 1 && tlen == 1)
    {
        return eq(s.front, t.front) ? 0 : 1;
    }

    if (slen < tlen)
    {
        Levenshtein!(Range1, eq, size_t) lev;
        return lev.distanceLowMem(s, t, slen, tlen, benchmark);
    }
    else
    {
        Levenshtein!(Range2, eq, size_t) lev;
        return lev.distanceLowMem(t, s, tlen, slen, benchmark);
    }
}

size_t levenshteinDistance(Range1, Range2)
    (Range1 s, Range2 t)
if (isForwardRange!(Range1) && isForwardRange!(Range2))
{
    auto slen = walkLength(s.save).to!int;
    auto tlen = walkLength(t.save).to!int;

    return levenshteinDistance(s, t, slen + tlen);
}

// original tests from standard library
unittest
{
    assert(levenshteinDistance("cat", "rat") == 1);
    assert(levenshteinDistance("parks", "spark") == 2);
    assert(levenshteinDistance("abcde", "abcde") == 0);
    assert(levenshteinDistance("abcde", "abCde") == 1);
    assert(levenshteinDistance("kitten", "sitting") == 3);
    assert(levenshteinDistance("ID", "I♥D") == 1);
}


// testing the benchmarking
unittest {
    assert(levenshteinDistance("Michigan", "Minnesota", 3) == 3);  // typically this would return 7
    assert(levenshteinDistance("Fifteen", "Fourteen", 2) == 2);  // typically this would return 4
}
