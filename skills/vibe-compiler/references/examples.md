# Worked examples

Self-contained, invented examples (no real/owned project code) showing how to label and link.
Two grammar "flavors": systems/struct and pipeline/dataflow.

## Example 1 — compile context, systems/struct flavor (LRU cache)

Given this pseudo, label and link as the tables below.

```csharp
// vbc/cache.vibe
struct LruCache<K, V>
{
    Dictionary<K, Node> map;
    Node head, tail;             // intrusive list, MRU at head
    List<(K, V)> _dirty;         // write-back buffer
    bool _writeBackEnabled;
    long hits, misses;
    long _evictLock;
}

partial struct LruCache<K, V>
{
    const int CAPACITY = ...;            // not specified

    V Get(K key)
    {
        node = map.Find(key);
        if (node == null) { misses++; return /* miss? */; }
        MoveToFront(node);               // LRU bookkeeping
        hits++; return node.value;
    }

    void Put(K key, V value)
    {
        if (map.Count >= CAPACITY)
            lock (_evictLock) Evict();   // drop least-recently-used
        InsertAtFront(key, value);
        if (_writeBackEnabled) MarkDirty(key, value);
    }
}
```

| Construct | Label | Why (axis) |
|---|---|---|
| `MoveToFront`, `InsertAtFront`, `Evict`, `map.Find` | **OK** | LRU fully implied by name |
| `return /* miss? */` on miss | **BLOCK** | axis 1 — throw vs `default(V)` vs Option is observably different error semantics |
| `CAPACITY = ...` | **BLOCK** → ASSUME if a policy/premise supplies it | governs memory + eviction; divergent + costly |
| `_evictLock` present, `Get` unsynchronized | **BLOCK** → OK if a "single-threaded" premise is declared | axis 2 — concurrency contract |
| `_dirty` flush timing unstated | **ASSUME + surface** | defensible default, cheap to change, surfaced |

**Symbol-paths.** Project linkage targets: the type `LruCache` (with field members
`LruCache.map`, `LruCache.head`, …), `LruCache.CAPACITY`, `LruCache.Get(K)`,
`LruCache.Put(K,V)`, `LruCache.Evict()`, `LruCache.MoveToFront`, `LruCache.InsertAtFront`,
`LruCache.MarkDirty`. The one-to-many "OK" row links a single pseudo line to the **set**
{`LruCache.MoveToFront`, `LruCache.InsertAtFront`, `LruCache.Evict()`}. Fields declared in the
pseudo are linkage targets; library calls on them (`map.Find`, `lock`) are not.

## Example 2 — compile context, pipeline/dataflow flavor (trending terms)

```python
# vbc/trending.vibe
# Find terms surging above their historical baseline rate.

def find_trending(events: Stream, window):
    counts = {}
    for e in window_of(events, window):
        counts[normalize(e.term)] += 1        # normalize: case-fold; stem?
    baseline = load_baseline_rates()
    out = []
    for term, c in counts:
        expected = baseline.get(term)         # term never seen before?
        if surprise(c, expected) > threshold: # surprise = ???
            out.append(term)
    return top_k(out, k)                       # k = ???

for window in tumbling_windows(events, every="1min"):
    find_trending(window, ...)
```

| Construct | Label | Why (axis) |
|---|---|---|
| `top_k`, `tumbling_windows` | **OK** | well-known |
| `normalize` | **ASSUME** | case-fold obvious; stemming surfaced as a sub-choice |
| `surprise(c, expected)` | **BLOCK** | axis 1 — ratio vs z-score vs KL give materially different results |
| `baseline.get(term)` for unseen term | **BLOCK** | missing value → div-by-zero / error semantics |
| `threshold`, `k` | **BLOCK** → ASSUME via policy/premise | unset critical config |
| per-window loop | **ASSUME** → BLOCK if stream declared huge | axis 3 — perf/scale |

**Symbol-paths.** Module = file stem `trending`. Linkage targets: `trending.find_trending`,
`trending.normalize`, `trending.surprise`, `trending.load_baseline_rates`, and the module-level
driver loop `for window in tumbling_windows(...)` → `trending.__main__`. Well-known library
calls (`top_k`, `tumbling_windows`, `window_of`) are not linkage targets.

## Example 3 — validate context, pseudo contradicts existing code

Validate is read-only and asks "does this pseudo faithfully describe what the code *currently
is*?" — not "what should it become."

```
# vbc/cache.vibe says:        Evict();   // drop least-recently-used   (tail)
# but existing Cache.cs has:  void Evict() => Remove(head);            // head = MRU

# /vbc-validate cache.vibe  ->  BLOCK (DIVERGED)
#   LruCache.Evict() — pseudo intent: drop LRU (tail).
#   Reality: drops head (MRU). Pseudo contradicts current code.
#   Resolve by either:
#     (a) the pseudo is meant to DESCRIBE reality -> fix the pseudo to match, or
#     (b) the divergence is an INTENDED change -> acknowledge it (status CHANGE_ACK), then
#         /vbc-compile applies the new behavior and re-links.
```

`NEW` vs `DIVERGED`: this BLOCK fires only when a symbol *exists* and the pseudo contradicts
it. A symbol absent from the whole codebase is `NEW` — recorded for creation, not blocked, so
greenfield pseudo validates cleanly. Validate cannot tell a mistaken description from an
intended change, so it hard-halts and makes the user choose.
