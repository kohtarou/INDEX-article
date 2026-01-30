-- ==========================================
-- 1. 環境セットアップ (再構築)
-- ==========================================
DROP TABLE IF EXISTS users_expert;

CREATE TABLE users_expert (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(100),
    score INT,
    category INT,
    pref_code INT,
    bio TEXT,  -- TOAST用 (大きなテキスト)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 100万件のデータ挿入
INSERT INTO users_expert (id, name, email, score, category, pref_code, bio, is_active)
SELECT
    i,
    'User_' || i,
    'user_' || i || '@example.com',
    (random() * 100)::INT,
    (random() * 100)::INT,
    (random() * 47 + 1)::INT,
    md5(random()::text),
    (random() > 0.1) -- 90% true, 10% false
FROM
    generate_series(1, 1000000) AS i;

-- 統計情報の更新
ANALYZE users_expert;


-- ==========================================
-- 2. 実験: Index Only Scan (カバリングインデックス)
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 7] Index Only Scan'
\echo '---------------------------------------------------'
-- 通常のインデックス
CREATE INDEX idx_score_expert ON users_expert(score);
ANALYZE users_expert;

-- Heap Fetch が発生する可能性がある (VM関連)
EXPLAIN ANALYZE SELECT score FROM users_expert WHERE score = 50;

-- INCLUDE オプション (PostgreSQL 11+)
DROP INDEX idx_score_expert;
CREATE INDEX idx_score_include ON users_expert(score) INCLUDE (id);
ANALYZE users_expert;

EXPLAIN ANALYZE SELECT id, score FROM users_expert WHERE score = 50;


-- ==========================================
-- 3. 実験: 部分インデックス (Partial Index)
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 8] Partial Index (Active Users Only)'
\echo '---------------------------------------------------'
-- アクティブでないユーザー (全体の10%) だけを検索したい
CREATE INDEX idx_inactive ON users_expert(id) WHERE is_active = false;
ANALYZE users_expert;

EXPLAIN ANALYZE SELECT * FROM users_expert WHERE is_active = false AND id = 12345;


-- ==========================================
-- 4. 実験: 関数インデックス (Functional Index)
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 9] Functional Index (Lower Email)'
\echo '---------------------------------------------------'
-- 大文字小文字を区別しない検索
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE lower(email) = 'user_12345@example.com';

CREATE INDEX idx_lower_email ON users_expert(lower(email));
ANALYZE users_expert;

EXPLAIN ANALYZE SELECT * FROM users_expert WHERE lower(email) = 'user_12345@example.com';


-- ==========================================
-- 5. 実験: LIKE 中間一致 vs 前方一致
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 10] LIKE Search'
\echo '---------------------------------------------------'
CREATE INDEX idx_name_expert ON users_expert(name text_pattern_ops);
ANALYZE users_expert;

-- 前方一致 (インデックス効く)
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE name LIKE 'User_100%';

-- 中間一致 (インデックス効かない)
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE name LIKE '%00';


-- ==========================================
-- 6. 実験: カーディナリティとSeq Scan
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 11] Boolean Search (High Cardinality)'
\echo '---------------------------------------------------'
CREATE INDEX idx_active ON users_expert(is_active);
ANALYZE users_expert;

-- 90%がTrueなので、Indexは使われないはず
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE is_active = true;

-- 10%がFalseなので、Indexが使われる可能性がある
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE is_active = false;


-- ==========================================
-- 7. 実験: OR検索とBitmap Or
-- ==========================================
\echo '---------------------------------------------------'
\echo '[Exp 12] OR Search'
\echo '---------------------------------------------------'
-- score用とcategory用のインデックス作成
CREATE INDEX idx_category_expert ON users_expert(category);
ANALYZE users_expert;

-- BitmapOr が出るか
EXPLAIN ANALYZE SELECT * FROM users_expert WHERE score = 50 OR category = 50;

