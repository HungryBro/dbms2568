```sql
-- account table
DROP TABLE account CASCADE;
CREATE TABLE account(
    account_id serial PRIMARY KEY,
    name text NOT NULL,
    dob date
);
```

```sql
-- thread table
DROP TABLE thread CASCADE;
CREATE TABLE thread(
    thread_id serial PRIMARY KEY,
    account_id integer NOT NULL REFERENCES account(account_id),
    title text NOT NULL
);
```

```sql
-- post table
DROP TABLE post CASCADE;
CREATE TABLE post(
    post_id serial PRIMARY KEY,
    thread_id integer NOT NULL REFERENCES thread(thread_id),
    account_id integer NOT NULL REFERENCES account(account_id),
    created timestamp with time zone NOT NULL DEFAULT now(),
    visible boolean NOT NULL DEFAULT TRUE,
    comment text NOT NULL
);
```


```sql
-- word table create with word in linux file
DROP TABLE words;
CREATE TABLE words (word TEXT) ;
\copy words (word) FROM '/data/words';
```

```sql
-- create account data
INSERT INTO account (name, dob)
SELECT
    substring('AEIOU', (random()*4)::int + 1, 1) ||
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1)::int, 1) || 
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1):: int, 1),
    Now() + ('1 days':: interval * random() * 365)
FROM generate_series (1, 100)
;
```

```sql
-- create thread data 
INSERT INTO thread (account_id, title)
WITH random_titles AS (
    -- 1. สร้างชื่อ Title สุ่มเตรียมไว้ 1,000 ชุด (หรือเท่ากับจำนวนที่ต้องการ insert)
    -- วิธีนี้จะทำการสุ่มคำเพียงครั้งเดียวต่อหนึ่ง title
    SELECT 
        row_number() OVER () as id,
        initcap(sentence) as title
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 5) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
)
SELECT
    (RANDOM() * 99 + 1)::int,
    rt.title
FROM generate_series(1, 1000) AS s(n)
JOIN random_titles rt ON rt.id = s.n
;
```

```sql
-- create post data
INSERT INTO post (thread_id, account_id, created, visible, comment)
WITH random_comments AS (
    SELECT row_number() OVER () as id, sentence
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 20) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
),
source_data AS (
    -- สร้างโครงข้อมูล 100,000 แถว พร้อมสุ่ม ID สำหรับเลือก comment
    SELECT 
        (RANDOM() * 999 + 1)::int AS t_id,
        (RANDOM() * 99 + 1)::int AS a_id,
        NOW() - ('1 days'::interval * random() * 1000) AS c_date,
        (RANDOM() > 0.1) AS vis,
        floor(random() * 1000 + 1)::int AS comment_id
    FROM generate_series(1, 100000)
)
SELECT 
    sd.t_id, 
    sd.a_id, 
    sd.c_date, 
    sd.vis, 
    rc.sentence
FROM source_data sd
JOIN random_comments rc ON sd.comment_id = rc.id -- ใช้ JOIN เพื่อการันตีว่าข้อมูลต้องมีค่า
;
```

## Step 1: Baseline Analysis
```sql
SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';

-- Output
 initial_size 
--------------
 29 MB
(1 row)

 n_live_tup | n_dead_tup
------------+------------
     100000 |          0
(1 row)
```

## Step 2: Create Massive Bloat
```sql
-- Run this UPDATE 5 times to create 500,000 dead tuples
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';


SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';


-- Output
UPDATE 100000
UPDATE 100000
UPDATE 100000
UPDATE 100000
UPDATE 100000
 initial_size 
--------------
 156 MB
(1 row)

 n_live_tup | n_dead_tup 
------------+------------
     100000 |     299984
(1 row)
```

## Step 3: Verify the Performance Hit
```sql
EXPLAIN ANALYZE SELECT count(*) FROM post;
-- Note the increased Execution Time due to scanning dead rows.
                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=5050.42..5050.43 rows=1 width=8) (actual time=28.742..28.743 rows=1 loops=1)
   ->  Index Only Scan using post_pkey on post  (cost=0.42..4800.42 rows=100000 width=0) (actual time=0.129..21.754 rows=100000 loops=1)
         Heap Fetches: 0
 Planning Time: 0.421 ms
 Execution Time: 28.792 ms
(5 rows)
-- Output 



```

## Step 4: Run Standard VACUUM
```sql
VACUUM (VERBOSE, ANALYZE) post;
-- Check size: It won't shrink, but n_dead_tup will go to 0.

-- Output
INFO:  vacuuming "db_6610301004.public.post"
INFO:  finished vacuuming "db_6610301004.public.post": index scans: 0
pages: 0 removed, 20018 remain, 1 scanned (0.00% of total)
tuples: 0 removed, 100000 remain, 0 are dead but not yet removable
removable cutoff: 9084, which was 1 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (0.00% of total) had 0 dead item identifiers removed
avg read rate: 85.852 MB/s, avg write rate: 0.000 MB/s
buffer usage: 3 hits, 13 misses, 0 dirtied
WAL usage: 0 records, 0 full page images, 0 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  vacuuming "db_6610301004.pg_toast.pg_toast_42544"
INFO:  finished vacuuming "db_6610301004.pg_toast.pg_toast_42544": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total)
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 9084, which was 1 XIDs old when operation ended
new relfrozenxid: 9084, which is 366 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 0.961 MB/s, avg write rate: 0.240 MB/s
buffer usage: 16 hits, 4 misses, 1 dirtied
WAL usage: 1 records, 1 full page images, 4813 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.03 s
INFO:  analyzing "public.post"
INFO:  "post": scanned 20018 of 20018 pages, containing 100000 live rows and 0 dead rows; 30000 rows in sample, 100000 estimated total rows
VACUUM
```

```sql

SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';

-- Output
 initial_size 
--------------
 156 MB
(1 row)

 n_live_tup | n_dead_tup
------------+------------
     100000 |          0
(1 row)


EXPLAIN ANALYZE SELECT count(*) FROM post;

                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=5050.42..5050.43 rows=1 width=8) (actual time=29.737..29.738 rows=1 loops=1)
   ->  Index Only Scan using post_pkey on post  (cost=0.42..4800.42 rows=100000 width=0) (actual time=0.093..22.463 rows=100000 loops=1)
         Heap Fetches: 0
 Planning Time: 0.249 ms
 Execution Time: 29.789 ms
(5 rows)
```


## Step 5: Run VACUUM FULL
```sql
VACUUM FULL post;
-- Check final size: The file will finally shrink on disk.
SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';

 -- Output
 initial_size 
--------------
 33 MB
(1 row)

 n_live_tup | n_dead_tup
------------+------------
     100000 |          0
(1 row)


EXPLAIN ANALYZE SELECT count(*) FROM post;

                                                    QUERY PLAN
------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=5417.00..5417.01 rows=1 width=8) (actual time=32.677..32.678 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..5167.00 rows=100000 width=0) (actual time=0.038..25.519 rows=100000 loops=1)
 Planning Time: 0.558 ms
 Execution Time: 32.727 ms
(4 rows)
```


