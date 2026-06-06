# Border report format

Written to `.vbc/reports/<command>-latest.md` each run.

```markdown
# vbc <validate|compile> report

## Summary
- files processed: 3 (cache, auth, trending)
- compiled: cache, auth          # compile only; omit on validate
- BLOCKED: trending               # -> NOTHING written this run (atomic)
- counts: ASSUME 2 . BLOCK 1 . promotions 1

## BLOCKs (must resolve before code is produced)
- [trending.surprise] axis 1 -- surprise(c,expected) underdetermined: ratio vs z-score vs KL.
  Resolve: specify in pseudo, or add a scoped policy.

## ASSUMEs (review)
- [cache.LruCache._dirty] flush-on-Evict assumed; change pseudo if undesired.

## Promotions (resolved under a declared assumption)
- [cache.LruCache.Get(K)] concurrency BLOCK->OK under premise "[scope: LruCache.*] single-threaded".
```

Rules:

- List **every** BLOCK with its axis and a concrete resolution hint.
- List **every** ASSUME.
- List **every** promotion (premise/policy) so a `BLOCK→OK` is never invisible.
- On compile, the Summary MUST state compiled-vs-blocked files and that a blocked run wrote
  nothing.
