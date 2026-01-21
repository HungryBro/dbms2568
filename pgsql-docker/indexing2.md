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
 post       | 28 MB      | 2208 kB    | 26 MB      |   100000
 thread     | 168 kB     | 40 kB      | 96 kB      |     1000
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
 Seq Scan on post  (cost=0.00..4584.00 rows=477 width=227) (actual time=0.196..23.706 rows=460 loops=1)
   Filter: (account_id = 1)
   Rows Removed by Filter: 99540
 Planning Time: 2.675 ms
 Execution Time: 23.767 ms
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
 Aggregate  (cost=4585.19..4585.20 rows=1 width=8) (actual time=26.699..26.701 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4584.00 rows=477 width=0) (actual time=0.183..26.647 rows=460 loops=1)
         Filter: (account_id = 1)
         Rows Removed by Filter: 99540
 Planning Time: 0.266 ms
 Execution Time: 26.752 ms
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
 Seq Scan on post  (cost=0.00..4584.00 rows=89 width=227) (actual time=0.433..32.030 rows=49 loops=1)
   Filter: (visible AND (thread_id = 1))
   Rows Removed by Filter: 99951
 Planning Time: 0.252 ms
 Execution Time: 32.085 ms
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
 Aggregate  (cost=4834.00..4834.01 rows=1 width=8) (actual time=27.687..27.689 rows=1 loops=1)
   ->  Seq Scan on post  (cost=0.00..4834.00 rows=1 width=0) (actual time=27.672..27.673 rows=0 loops=1)
         Filter: (visible AND (thread_id = 1) AND (account_id = 1))
         Rows Removed by Filter: 100000
 Planning Time: 0.344 ms
 Execution Time: 27.778 ms
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
------------------------------------------------------------------------------------------------------------------------
 Gather Merge  (cost=5167.37..5167.60 rows=2 width=227) (actual time=19.534..21.779 rows=3 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Sort  (cost=4167.34..4167.35 rows=1 width=227) (actual time=9.494..9.494 rows=1 loops=3)
         Sort Key: created
         Sort Method: quicksort  Memory: 25kB
         Worker 0:  Sort Method: quicksort  Memory: 25kB
         Worker 1:  Sort Method: quicksort  Memory: 25kB
         ->  Parallel Seq Scan on post  (cost=0.00..4167.33 rows=1 width=227) (actual time=7.572..9.424 rows=1 loops=3)
               Filter: (visible AND (thread_id = 1) AND (created > (now() - '1 mon'::interval)))
               Rows Removed by Filter: 33332
 Planning Time: 0.225 ms
 Execution Time: 21.817 ms
(13 rows)

```


## CREATE INDEXES

### Case A Baseline

```sql
EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 
```

### Case B Single Index

```sql
CREATE INDEX post_account_id_idx ON post(account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE account_id = 1; 
```

### Case C Composite Index

```sql
DROP INDEX post_account_id_idx;

CREATE INDEX post_thread_id_account_id_idx ON post(thread_id, account_id);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1;
```

### Case D Full Composite Index

```sql
DROP INDEX post_thread_id_account_id_idx;

CREATE INDEX post_thread_id_account_id_visible_idx ON post(thread_id, account_id, visible);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND account_id = 1 AND visible = TRUE;
```

### Case E Partial Index

```sql
DROP INDEX post_thread_id_account_id_visible_idx;

CREATE INDEX post_thread_id_visible_idx ON post(thread_id) WHERE visible = TRUE;

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 AND visible = TRUE;
```

### Case F Sorting

```sql
DROP INDEX post_thread_id_visible_idx;

CREATE INDEX post_thread_id_create_idx ON post(thread_id, created DESC);

EXPLAIN ANALYZE
SELECT * FROM post WHERE thread_id = 1 ORDER BY created DESC LIMIT 10;

```
