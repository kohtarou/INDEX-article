-- ==========================================
-- 8. 実験: 理論検証用データ収集 (コスト計算用)
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Theory 1] Physical Stats for Cost Calculation'
\echo '---------------------------------------------------'

ANALYZE users_expert;

-- テーブルの物理サイズとページ数、タプル数
SELECT
    relname,
    relpages AS "Total Pages (8KB blocks)",
    reltuples AS "Total Rows",
    pg_size_pretty(pg_total_relation_size('users_expert')) AS "Total Size",
    pg_size_pretty(pg_relation_size('users_expert')) AS "Heap Size",
    pg_size_pretty(pg_indexes_size('users_expert')) AS "Index Size"
FROM pg_class
WHERE relname = 'users_expert';

-- コストパラメータの確認
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;
SHOW cpu_index_tuple_cost;
SHOW cpu_operator_cost;

-- 実際のコスト計算の答え合わせ用
\echo '---------------------------------------------------'
\echo '[Theory 2] Confirm Seq Scan Cost'
\echo '---------------------------------------------------'
EXPLAIN (FORMAT JSON, ANALYZE) SELECT * FROM users_expert WHERE score = 50;

-- インデックスの高さ(Height)とメタデータ確認 (pg_statio_user_indexesなど)
-- ※pageinspect拡張は入れられない可能性が高いので、標準ビューのみで推測
SELECT
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'users_expert';
