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