# Indexing 

StudentID :

StudentName: 

```sql
-- account table
CREATE TABLE account(
    account_id serial PRIMARY KEY,
    name text NOT NULL,
    dob date
);
```

```sql
-- thread table
CREATE TABLE thread(
    thread_id serial PRIMARY KEY,
    account_id integer NOT NULL REFERENCES account(account_id),
    title text NOT NULL
);
```

```sql
-- post table
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


# WITHOUT INDEXING

```sql
-- table and index data
SELECT
    t.table_name,
    pg_size_pretty(pg_total_relation_size('public.' || t.table_name)) AS total_size,
    pg_size_pretty(pg_indexes_size('public.' || t.table_name)) AS index_size,
    pg_size_pretty(pg_relation_size('public.' || t.table_name)) AS table_size,
    COALESCE(pg_class.reltuples::bigint, 0) AS num_rows
FROM
    information_schema.tables t
LEFT JOIN
    pg_class ON pg_class.relname = t.table_name
LEFT JOIN
    pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE
    t.table_schema = 'public'
    AND pg_namespace.nspname = 'public'
ORDER BY
    t.table_name ASC
;
-- Output
 table_name | total_size | index_size | table_size | num_rows 
------------+------------+------------+------------+----------
 account    | 32 kB      | 16 kB      | 8192 bytes |      100
 post       | 29 MB      | 2208 kB    | 27 MB      |   100000
 thread     | 176 kB     | 40 kB      | 104 kB     |     1000
 words      | 10024 kB   | 0 bytes    | 9984 kB    |   235976
(4 rows)

```


### Exercise 2 See all my posts
```sql
-- Query 1: See all my posts
EXPLAIN ANALYZE
SELECT * FROM post
WHERE account_id = 1
;

-- Output
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4699.00 rows=520 width=239) (actual time=0.095..38.892 rows=499 loops=1)
   Filter: (account_id = 1)
   Rows Removed by Filter: 99501
 Planning Time: 0.434 ms
 Execution Time: 38.967 ms
(5 rows)

```

### Exercise 3 How many post have i made?
```sql
-- Query 2: How many post have i made?
EXPLAIN ANALYZE
SELECT COUNT(*) FROM post
WHERE account_id = 1;

-- Output
                                                 QUERY PLAN
------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=4700.30..4700.31 rows=1 width=8) (actual time=31.830..31.833 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4699.00 rows=520 width=0) (actual time=0.084..31.742 rows=499 loops=1)
         Filter: (account_id = 1)
         Rows Removed by Filter: 99501
 Planning Time: 0.271 ms
 Execution Time: 31.897 ms
(6 rows)

```

### Exercise 4 See all current posts for a Thread

```sql
-- Query 3: See all current posts for a Thread
EXPLAIN ANALYZE
SELECT * FROM post
WHERE thread_id = 1
AND visible = TRUE;

-- Output
                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4699.00 rows=88 width=239) (actual time=1.866..36.467 rows=36 loops=1)
   Filter: (visible AND (thread_id = 1))
   Rows Removed by Filter: 99964
 Planning Time: 0.156 ms
 Execution Time: 36.511 ms
(5 rows)

```

### Exercise 5 How many posts have i made to a Thread?

```sql
-- Query 4: How many posts have i made to a Thread?
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM post
WHERE thread_id = 1 AND visible = TRUE AND account_id = 1;

-- Output
                                               QUERY PLAN
---------------------------------------------------------------------------------------------------------
 Aggregate  (cost=4949.00..4949.01 rows=1 width=8) (actual time=31.404..31.406 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4949.00 rows=1 width=0) (actual time=31.396..31.396 rows=0 loops=1)
         Filter: (visible AND (thread_id = 1) AND (account_id = 1))
         Rows Removed by Filter: 100000
 Planning Time: 0.320 ms
 Execution Time: 31.468 ms
(6 rows)

```

### Exercise 6 See all current posts for a Thread for this month, in order

```sql
-- Query 5: See all current posts for a Thread for this month, in order
EXPLAIN ANALYZE
SELECT *
FROM post
WHERE thread_id = 1 AND visible = TRUE AND created > NOW() - '1 month'::interval
ORDER BY created;

-- Output
                                                        QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------
 Gather Merge  (cost=5282.37..5282.60 rows=2 width=239) (actual time=21.592..25.513 rows=1 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Sort  (cost=4282.34..4282.35 rows=1 width=239) (actual time=12.948..12.949 rows=0 loops=3)
         Sort Key: created
         Sort Method: quicksort  Memory: 25kB
         Worker 0:  Sort Method: quicksort  Memory: 25kB
         Worker 1:  Sort Method: quicksort  Memory: 25kB
         ->  Parallel Seq Scan on post  (cost=0.00..4282.33 rows=1 width=239) (actual time=10.725..12.791 rows=0 loops=3)
               Filter: (visible AND (thread_id = 1) AND (created > (now() - '1 mon'::interval)))
               Rows Removed by Filter: 33333
 Planning Time: 0.359 ms
 Execution Time: 25.569 ms
(13 rows)

```


## CREATE INDEXES

### Case A Baseline

```sql
EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 

-- output
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Seq Scan on post  (cost=0.00..4699.00 rows=520 width=239) (actual time=0.188..30.832 rows=499 loops=1)
   Filter: (account_id = 1)
   Rows Removed by Filter: 99501
 Planning Time: 0.127 ms
 Execution Time: 30.904 ms
(5 rows)
```

### Case B Single Index

```sql
CREATE INDEX post_account_id_idx ON post(account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 
-- output
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on post  (cost=8.32..1406.89 rows=520 width=239) (actual time=0.359..1.414 rows=499 loops=1)
   Recheck Cond: (account_id = 1)
   Heap Blocks: exact=472
   ->  Bitmap Index Scan on post_account_id_idx  (cost=0.00..8.19 rows=520 width=0) (actual time=0.193..0.194 rows=499 loops=1)
         Index Cond: (account_id = 1)
 Planning Time: 0.390 ms
 Execution Time: 1.535 ms
(7 rows)

EXPLAIN ANALYZE
SELECT count(*) FROM post WHERE account_id = 1;
-- output
                                                                    QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=3071.31..3071.32 rows=1 width=8) (actual time=11.819..11.822 rows=1 loops=1)
   ->  Bitmap Heap Scan on post  (cost=1718.42..3070.06 rows=497 width=0) (actual time=6.832..11.714 rows=499 loops=1)
         Recheck Cond: (account_id = 1)
         Heap Blocks: exact=472
         ->  Bitmap Index Scan on post_thread_id_account_id_idx  (cost=0.00..1718.29 rows=497 width=0) (actual time=6.692..6.693 rows=499 loops=1)
               Index Cond: (account_id = 1)
 Planning Time: 0.190 ms
 Execution Time: 11.905 ms
(8 rows)
```

### Case C Composite Index

```sql
DROP INDEX post_account_id_idx;

CREATE INDEX post_thread_id_account_id_idx ON post(thread_id, account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1;
-- output
                                                              QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using post_thread_id_account_id_idx on post  (cost=0.29..8.31 rows=1 width=239) (actual time=0.017..0.018 rows=0 loops=1)
   Index Cond: ((thread_id = 1) AND (account_id = 1))
 Planning Time: 0.296 ms
 Execution Time: 0.046 ms
(4 rows)
```

### Case D Full Composite Index

```sql
DROP INDEX post_thread_id_account_id_idx;

CREATE INDEX post_thread_id_account_id_visible_idx ON post(thread_id, account_id, visible);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1 AND visible = TRUE;
-- output
                                                                  QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using post_thread_id_account_id_visible_idx on post  (cost=0.42..8.44 rows=1 width=239) (actual time=0.047..0.048 rows=0 loops=1)
   Index Cond: ((thread_id = 1) AND (account_id = 1) AND (visible = true))
 Planning Time: 0.667 ms
 Execution Time: 0.083 ms
(4 rows)
```

### Case E Partial Index

```sql
DROP INDEX post_thread_id_account_id_visible_idx;

CREATE INDEX post_thread_id_visible_idx ON post(thread_id) WHERE visible = TRUE;

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND visible = TRUE;
-- output
                                                             QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on post  (cost=4.97..312.62 rows=88 width=239) (actual time=0.088..0.186 rows=36 loops=1)
   Recheck Cond: ((thread_id = 1) AND visible)
   Heap Blocks: exact=36
   ->  Bitmap Index Scan on post_thread_id_visible_idx  (cost=0.00..4.95 rows=88 width=0) (actual time=0.048..0.049 rows=36 loops=1)
         Index Cond: (thread_id = 1)
 Planning Time: 0.711 ms
 Execution Time: 0.224 ms
(7 rows)
```

### Case F Sorting

```sql
DROP INDEX post_thread_id_visible_idx;

CREATE INDEX post_thread_id_create_idx ON post(thread_id, created DESC);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 ORDER BY created DESC LIMIT 10;
-- Output
                                                                 QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.42..40.59 rows=10 width=239) (actual time=0.052..0.079 rows=10 loops=1)
   ->  Index Scan using post_thread_id_create_idx on post  (cost=0.42..394.12 rows=98 width=239) (actual time=0.050..0.073 rows=10 loops=1)
         Index Cond: (thread_id = 1)
 Planning Time: 0.626 ms
 Execution Time: 0.112 ms
(5 rows)
```

### Case G Join

```sql
DROP INDEX IF EXISTS post_thread_id_create_idx;

CREATE INDEX post_account_id_idx ON post(account_id);

EXPLAIN ANALYZE
SELECT post.comment, account.name
FROM post 
JOIN account ON post.account_id = account.account_id
WHERE post.account_id = 1;
-- Output
                                                              QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=8.45..1449.38 rows=537 width=225) (actual time=0.362..1.808 rows=499 loops=1)
   ->  Seq Scan on account  (cost=0.00..2.25 rows=1 width=11) (actual time=0.020..0.038 rows=1 loops=1)
         Filter: (account_id = 1)
         Rows Removed by Filter: 99
   ->  Bitmap Heap Scan on post  (cost=8.45..1441.76 rows=537 width=222) (actual time=0.336..1.579 rows=499 loops=1)
         Recheck Cond: (account_id = 1)
         Heap Blocks: exact=472
         ->  Bitmap Index Scan on post_account_id_idx  (cost=0.00..8.32 rows=537 width=0) (actual time=0.172..0.173 rows=499 loops=1)
               Index Cond: (account_id = 1)
 Planning Time: 0.756 ms
 Execution Time: 1.911 ms
(11 rows)
```

### Case H Join with Aggregate

```sql
DROP INDEX IF EXISTS post_account_id_idx;

CREATE INDEX post_account_id_post_id_idx ON post(account_id, post_id);

EXPLAIN ANALYZE
SELECT account.name, count(post.post_id) 
FROM account 
LEFT JOIN post ON account.account_id = post.account_id 
GROUP BY account.name;

-- Output
                                                       QUERY PLAN
------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=5225.88..5226.88 rows=100 width=15) (actual time=66.463..66.476 rows=100 loops=1)
   Group Key: account.name
   Batches: 1  Memory Usage: 24kB
   ->  Hash Right Join  (cost=3.25..4725.88 rows=100000 width=11) (actual time=0.210..46.878 rows=100000 loops=1)
         Hash Cond: (post.account_id = account.account_id)
         ->  Seq Scan on post  (cost=0.00..4449.00 rows=100000 width=8) (actual time=0.024..27.528 rows=100000 loops=1)
         ->  Hash  (cost=2.00..2.00 rows=100 width=11) (actual time=0.140..0.141 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 13kB
               ->  Seq Scan on account  (cost=0.00..2.00 rows=100 width=11) (actual time=0.046..0.092 rows=100 loops=1)
 Planning Time: 0.894 ms
 Execution Time: 66.570 ms
(11 rows)
```