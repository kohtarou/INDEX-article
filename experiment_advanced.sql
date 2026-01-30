-- ==========================================
-- 1. 環境セットアップ
-- ==========================================
DROP TABLE IF EXISTS users_experiment;

CREATE TABLE users_experiment (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    score INT,
    category INT,   -- 新追加: 複合インデックス実験用
    pref_code INT,  -- 新追加: カーディナリティ実験用 (1-47)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 100万件のデータ挿入 (category: 0-100, pref_code: 1-47)
INSERT INTO users_experiment (id, name, score, category, pref_code)
SELECT
    i,
    'User_' || i,
    (random() * 100)::INT,
    (random() * 100)::INT,
    (random() * 47 + 1)::INT
FROM
    generate_series(1, 1000000) AS i;

ANALYZE users_experiment;

-- ==========================================
-- 2. 基本実験: Seq Scan vs Index Scan
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 1] Seq Scan (Score=50)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE score = 50;

CREATE INDEX idx_score ON users_experiment(score);
ANALYZE users_experiment;

\echo '---------------------------------------------------'
\echo '[Exp 1] Index Scan (Score=50)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE score = 50;


-- ==========================================
-- 3. 発展実験: 複合インデックス (Category, Score)
-- ==========================================
-- 複合インデックス作成
CREATE INDEX idx_cat_score ON users_experiment(category, score);
ANALYZE users_experiment;

-- ケースA: 両方指定 (インデックス効く)
\echo '---------------------------------------------------'
\echo '[Exp 2-A] Composite Index (Category=50 AND Score=50)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE category = 50 AND score = 50;

-- ケースB: 左側のみ指定 (インデックス効く)
\echo '---------------------------------------------------'
\echo '[Exp 2-B] Left Prefix (Category=50)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE category = 50;

-- ケースC: 右側のみ指定 (インデックス効かない可能性大)
\echo '---------------------------------------------------'
\echo '[Exp 2-C] Right Only (Score=50) - using composite index?'
\echo '---------------------------------------------------'
-- idx_scoreがあるので、それを削除して純粋に複合インデックス挙動を見る
DROP INDEX idx_score;
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE score = 50;


-- ==========================================
-- 4. 発展実験: 範囲検索とソート
-- ==========================================
-- idx_score を再作成
CREATE INDEX idx_score ON users_experiment(score);
ANALYZE users_experiment;

\echo '---------------------------------------------------'
\echo '[Exp 3] Range Scan (Score BETWEEN 10 AND 20)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE score BETWEEN 10 AND 20;

\echo '---------------------------------------------------'
\echo '[Exp 4] Sort Avoidance (ORDER BY score)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment ORDER BY score LIMIT 10;
-- LIMITがないと全件取得でSeq Scanになる可能性があるためLIMITをつける


-- ==========================================
-- 5. 発展実験: インデックスが効かないケース
-- ==========================================

\echo '---------------------------------------------------'
\echo '[Exp 5] Calculation in WHERE (score + 10 = 50)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE score + 10 = 50;

\echo '---------------------------------------------------'
\echo '[Exp 6] Low Selectivity (High Cardinality) - pref_code'
\echo '---------------------------------------------------'
-- pref_code (1-47) にインデックスを作成
CREATE INDEX idx_pref ON users_experiment(pref_code);
ANALYZE users_experiment;

-- 全体の約1/47 (約2%) なのでインデックスが使われるはず
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE pref_code = 13;

-- 強制的に大量ヒットさせる (例: > 0 つまり全件) -> Seq Scanになるはず
\echo '---------------------------------------------------'
\echo '[Exp 6-B] High Hit Rate (> 0)'
\echo '---------------------------------------------------'
EXPLAIN ANALYZE SELECT * FROM users_experiment WHERE pref_code > 0;
