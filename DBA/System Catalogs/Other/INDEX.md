<center><h1>Indexes in PGSQL</h1></center>

<br>
<br>

- [In simple words:](#in-simple-words)
- [Why indexes exist?](#why-indexes-exist)
- [How PGSQL stores table data (important context)](#how-pgsql-stores-table-data-important-context)
- [What an **`index`** actually stores](#what-an-index-actually-stores)
- [Default index type: **`B-Tree`**](#default-index-type-b-tree)
- [How a **`B-tree`** index works internally](#how-a-b-tree-index-works-internally)
- [Internal Query Flow (Step by step flow)](#internal-query-flow-step-by-step-flow)
  - [Step 1 Root page](#step-1-root-page)
  - [Step 3 Intermediate Page](#step-3-intermediate-page)
  - [Step 3 Leaf Page](#step-3-leaf-page)
  - [Step 4 Heap Fetch](#step-4-heap-fetch)
- [Index-only scan (fastest case)](#index-only-scan-fastest-case)
- [When PGSQL does NOT use an index](#when-pgsql-does-not-use-an-index)
- [Cost of having indexes](#cost-of-having-indexes)
- [Index Maintenance Internally](#index-maintenance-internally)
- [Why index bloat happens](#why-index-bloat-happens)
- [When I use indexes](#when-i-use-indexes)
- [Summary](#summary)
- [Basic Index Creation](#basic-index-creation)
- [How PGSQL Uses an Index (Practical Flow)](#how-pgsql-uses-an-index-practical-flow)
- [Why PGSQL Ignores an Existing Index](#why-pgsql-ignores-an-existing-index)
- [Composite (Multi-Column) Indexes](#composite-multi-column-indexes)
- [Indexes for ORDER BY and LIMIT](#indexes-for-order-by-and-limit)
- [Index-only scan (fastest case)](#index-only-scan-fastest-case-1)
- [Cost of indexes (very important)](#cost-of-indexes-very-important)
- [Updates, MVCC and Index Bloat](#updates-mvcc-and-index-bloat)
- [Detecting Index Size Growth](#detecting-index-size-growth)
- [Reindexing (use carefully)](#reindexing-use-carefully)
- [Partial Index](#partial-index)


<br>
<br>

## In simple words:
- An index in PGSQL is a separate structure that helps the database to find rows faster by avoiding full table scans (also known as **`seq_scan`** (sequential scan)).
- It works like a shortcut that maps column values to the physical location of rows in a table.

<br>

- Indexes improve read performance, but they always come with a write cost.

---

<br>
<br>

## Why indexes exist?
- Tables store data in no particular order on disk.
- If PGSQL had to scan every row for every query, performance would collapse as data grows.

<br>

- Indexes exist for:
  - Reduce disk reads
  - Avoid scanning unnecessary rows
  - Make data access predictable at scale
- Speed is a result, not the main goal.
- The real goal is less data to scan.

---

<br>
<br>

## How PGSQL stores table data (important context)
- PGSQL tables are stored as heap files:
  - Rows are unordered
  - Data lives in fixed-size disk pages
  - PGSQL does not know where a specific value is without scanning
- Indexes solve this problem.

---

<br>
<br>

## What an **`index`** actually stores
- An **`index`** does not store full rows.

<br>

- It stores:
  - Indexed column value
  - Physical row location (called **`TID`** - Tuple ID)
- **`TID`** points to:
  - block number
  - row offset inside that block
- This is why PGSQL still needs to visit the table unless it can do an **`index-only`** scan.

---

<br>
<br>

## Default index type: **`B-Tree`**
- **`B-tree`** is the most commonly used index in PGSQL.

<br>

- It supports:
  - equality (**`=`**)
  - range queries (**`>`**, **`<`**, **`BETWEEN`**)
  - sorting (**`ORDER BY`**)
  - uniqueness
- Most production workloads rely heavily on **`B-tree`** indexes.

---

<br>
<br>

## How a **`B-tree`** index works internally
- A **`B-tree`** made of pages arranged in level:
    1. Root page
    2. Intermediate pages
    3. Leaf pages

The search path is always:
```bash
Root -> Intermediate -> Leaf
```

---

<br>
<br>

## Internal Query Flow (Step by step flow)
Query Example:
```sql
SELECT * FROM users WHERE user_id = 105;
```
> Assume `user_id` has a B-tree index.

<br>
<br>

### Step 1 Root page
- PGSQL checks the root page to decide which branch contains value **`105`**.
- The root never contains data itself - only directions.

<br>
<br>

### Step 3 Intermediate Page
- The value range is narrowed further
- PGSQL decides which child page to follow next.

<br>
<br>

### Step 3 Leaf Page
- The leaf page contains:
  - **`user_id = 105`**
  - its **`TID`** (Physical Location)
- This is the first time PGSQL knows exactly where the row is.

<br>
<br>

### Step 4 Heap Fetch
- Using the **`TID`**, PGSQL goes to the table (HEAP) and fetches the actual row.
- This step is required because indexes do not store full row data.

---

<br>
<br>

## Index-only scan (fastest case)
- If:
  - the query uses only indexed columns
  - the visibility map confirms rows are visible.
- PGSQL can skip the heap completely.
- This is called index-only scan and is the fastest possible access path.

---

<br>
<br>

## When PGSQL does NOT use an index
- Indexes are not automatically used just because they exist.

<br>

- Common Reasons:
  - Table is very small (sequential scan is cheaper)
  - Condition matches a large percentage of rows
  - Planner statistics are outdated.
  - Functions are used on indexed columns
  - Index selectivity is poor
- The planner always chooses the cheapest plan, not the most obvious one.

---

<br>
<br>

## Cost of having indexes
- Every index adds overhead.

<br>

- Indexes make:
  - **`INSERT`** slower
  - **`UPDATE`** slower
  - **`DELETE`** slower
  - **`VACUUM`** heavier
  - Disk usage larger
- A useless index is worse than no index.

---

<br>
<br>

## Index Maintenance Internally
- **`INSERT`** adds a new index entry
- **`UPDATE`** create a new row version and new index entry
- **`DELETE`** marks index entries dead
- **`VACUUM`** cleans dead entries

Heavy **`UPDATE`** and **`DELETE`** activity causes index bloat over time.

---

<br>
<br>

## Why index bloat happens
- PGSQL uses **`MVCC`**
- Old row versions and old index entries remain until vacuum removes them.

<br>

- Frequent updates + weak vacuum = growing indexes.

---

<br>
<br>

## When I use indexes
- I create an index when:
  - Queries frequently filter on specific columns
  - The condition is selective
  - Read performance matters more than write cost
- I avoid indexes when:
  - Data changes constantly
  - Conditions match most rows
  - The table is very small

<br>
<details>
<summary><mark><b>Explained with Examples</b></mark></summary>
<br>

**When i create an index**

> Filtering on a column usedd often in queries:
```sql
CREATE INDEX idx_users_email ON users(email);
```

<br>
<br>

> When the condition is selective (few rows returned):
```sql
SELECT * FROM users WHERE email = "prashant@gmail.com";
```

<br>
<br>

> When read performance is more important then write cost:
```sql
CREATE INDEX idx_orders_created_at ON orders(created_at);
```

<br>
<br>

**When I avoid indexes:**

> When data changes constantly (heavy inserts or updates):
```sql
UPDATE logs SET status = 'done' WHERE processed = flase;
```

<br>
<br>

> When conditions match most rows (index wont help)
```sql
SELECT * FROM orders WHERE status IS NOT NULL;
```

<br>
<br>

> When the table is very small:
```sql
SELECT * FROM country_codes;
```


</details>
<br>

---

## Summary
- <u><b>Index</b></u>: A separate structure that maps column values to physical row locations to reduce table scans.
- <u><b>B-tree</b></u> <u><b>index</b></u>: A balanced tree structure used by PGSQL for fast equality and range searches.
- <u><b>Index only scan</b></u>: A scan where PGSQL returns results directly from the index without visiting the table.

<br>

**Final mental model**
- <u><b>Table</b></u> = unordered data on disk
- <u><b>Index</b></u> = sorted pointer structure
- Planner decides index vs sequential scan
- Index speeds up reads, slows down writes
- Wrong indexes hurt performance

---

<br>
<br>
<br>
<br>

<center><h1>Indexes in PGSQL - Practical Guide</h1></center>
<br>
<br>

## Basic Index Creation
**Example table:**
```sql
CREATE TABLE(
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    status TEXT,
    created_at TIMESTAMP,
    amount NUMERIC
);
```

<br>
<br>

**Basic Index:**
```sql
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

<br>
<br>

**This helps queries like:**
```sql
SELECT * FROM orders WHERE user_id = 101;
```

---

<br>
<br>

## How PGSQL Uses an Index (Practical Flow)
1. Planner checks if an index exists
2. Planner estimates cost of index scan vs sequential scan
3. If index scan is cheaper:
   1. PGSQL walks the B-tree
   2. Finds TID (row location)
   3. Fetches row from heap
4. Otherwise, it uses sequential scan

Planner always chooses the cheapest plan, not the one with an index.

---

<br>
<br>

## Why PGSQL Ignores an Existing Index
- **Small table:** If the tables has very few rows, sequential scan is faster.
- **Low selectivity:** If most rows match the condition, index becomes useless.

<br>

**Example:**
```sql
WHERE status = 'ACTIVE';
```
> If 90% rows are ACTIVE, PGSQL prefers sequential scan.

<br>
<br>

- **Functions on indexed columns:**

```sql
WHERE LOWER(status) = 'pending';
```

> If an index exist on `status`, it cannot be used here.

<br>

**Solution:**
```sql
CREATE INDEX idx_lower_status ON orders(LOWER(status));
```

<br>
<br>

- **Outdated statistics:**
Planner decisions depend on statustics.

**Fix:**
```sql
ANALYZE;
```

<br>
<br>

## Composite (Multi-Column) Indexes
**Query:**
```sql
SELECT * FROM orders 
WHERE user_id = 101 AND status = "PAID";
```

**Correct Index:**
```sql
CREATE INDEX idx_orders_user_status 
ON orders (user_id, status);
```

**Important Rule:**
- Index works left to right
- Column order matters

---

<br>
<br>

## Indexes for ORDER BY and LIMIT
**Query:**
```sql
SELECT * FROM orders
WHERE user_id = 101
ORDER BY created_at DESC
LIMIT 10;
```

**Best Index:**
```sql
CREATE INDEX idx_orders_user_created
ON order (user_id, created_at DESC);
```

> This avoids sorting and speeds up paginations queries.

<br>
<br>

## Index-only scan (fastest case)
**Query:**
```sql
SELECT user_id FROM orders WHERE user_id = 101;
```

If:
- Index contains all required columns
- Visibility map is clean

> PGSQL skips heap access and returns data directly from index.

---

<br>
<br>

## Cost of indexes (very important)
Each index makes:
- INSERT slower
- UPDATE slower
- DELETE slower
- VACUUM heavier
- Disk usage higher

Indexes are not free. <br>
Too many indexes = slow writes.

---

<br>
<br>

## Updates, MVCC and Index Bloat
- When a row is updated:
  - PGSQL creates a new row version
  - Old row becomes dead
  - New index entry is created
  - Old index entry stays until vacuum.
- Frequent updates cause index bloat.

---

<br>
<br>

## Detecting Index Size Growth
```sql
SELECT
    relname,
    pg_size_pretty(pg_relation_size(relid))
FROM pg_stat_user_indexes;
```

> If an index size keeps growing without data growth, bloat is likely.

---

<br>
<br>

## Reindexing (use carefully)
```sql
REINDEX INDEX idx_orders_user_id;
```

**Reindex can:**
- Bloack queries
- Cause performance impact

Use only when necessary. <br>
Autovacuum tunning is usually better.

---

<br>
<br>

## Partial Index

If a query targets a small subset of data:
```sql
SELECT * FROM orders WHERE staus = "PENDING";
```

**Create partial index:**
```sql
CREATE INDEX idx_pending_orders
ON orders(user_id)
WHERE status = 'PENDING';
```
> This creates a smaller, more efficient index.

