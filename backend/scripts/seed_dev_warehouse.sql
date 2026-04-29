-- Сидер тестовых данных склада с вложенностью (parent_item_id + варианты).
-- Привязывает позиции к личной организации samsonovartem00@gmail.com.
-- Есть группа «Сок тест · один литраж»: две подпозиции с одним литражем упаковки (1 л) и одинаковой подписью,
-- но разными сроками годности — чтобы проверить различение строк в стаке.
-- Идемпотентно: фикс UUID + ON CONFLICT (id) DO NOTHING.
--
-- Запуск:
--   make seed-warehouse
-- или:
--   cat backend/scripts/seed_dev_warehouse.sql \
--     | docker compose -f backend/docker-compose.yml exec -T postgres \
--         psql -U cstati -d cstatiwarehouse

\set ON_ERROR_STOP on

-- Проверка контекста: юзер и его личная организация должны существовать.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM users u
          JOIN organizations o ON o.owner_id = u.id AND o.is_personal = TRUE
         WHERE u.email = 'samsonovartem00@gmail.com'
    ) THEN
        RAISE EXCEPTION 'Не найден пользователь samsonovartem00@gmail.com или его личная организация';
    END IF;
END $$;

BEGIN;

-- 1) Корневые позиции (5 штук) с вариантами.
-- У корня с вариантами quantity=0, measure_unit='piece' — UI агрегирует литры по детям.
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organizations o ON o.owner_id = u.id AND o.is_personal = TRUE
     WHERE u.email = 'samsonovartem00@gmail.com'
),
roots(id, name, description, category_name, created_at) AS (
    VALUES
        ('a1000000-0000-4000-a000-000000000001'::uuid, 'Сок яблочный Rich',         'осветлённый',     'напитки', NOW() - INTERVAL '7 days'),
        ('a1000000-0000-4000-a000-000000000002'::uuid, 'Молоко Простоквашино 3,2%', '',                'напитки', NOW() - INTERVAL '12 days'),
        ('a1000000-0000-4000-a000-000000000003'::uuid, 'Пиво Жигулёвское',          '',                'напитки', NOW() - INTERVAL '8 days'),
        ('a1000000-0000-4000-a000-000000000004'::uuid, 'Вода Бонаква',              'негазированная',  'напитки', NOW() - INTERVAL '15 days'),
        ('a1000000-0000-4000-a000-000000000005'::uuid, 'Сок тест · один литраж',    'две партии по 1 л, разный срок годности', 'напитки', NOW() - INTERVAL '1 day')
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, parent_item_id, variant_label, measure_unit, volume_per_unit,
    created_at, updated_at
)
SELECT r.id, ctx.org_id, ctx.user_id, r.name, r.description, r.category_name,
       0, 'in_stock', NULL, '', 'piece', NULL,
       r.created_at, r.created_at
  FROM roots r CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

-- 2) Варианты под корнями (фасовки в литрах).
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organizations o ON o.owner_id = u.id AND o.is_personal = TRUE
     WHERE u.email = 'samsonovartem00@gmail.com'
),
variants(id, parent_id, name, variant_label, volume_per_unit, quantity, expires_in_days, created_in_days_ago) AS (
    VALUES
        -- Сок Rich: 1 л × 6, 2 л × 4
        ('b1000000-0000-4000-a000-000000000001'::uuid, 'a1000000-0000-4000-a000-000000000001'::uuid, 'Сок яблочный Rich',         '1 л',           1.0,  6,  12,  7),
        ('b1000000-0000-4000-a000-000000000002'::uuid, 'a1000000-0000-4000-a000-000000000001'::uuid, 'Сок яблочный Rich',         '2 л',           2.0,  4,  60,  2),
        -- Молоко: 1 л / 0,5 л / 0,2 л — последний просрочен (in_stock с прошедшей датой → красный бейдж)
        ('b1000000-0000-4000-a000-000000000010'::uuid, 'a1000000-0000-4000-a000-000000000002'::uuid, 'Молоко Простоквашино 3,2%', '1 л',           1.0,  8,   4,  3),
        ('b1000000-0000-4000-a000-000000000011'::uuid, 'a1000000-0000-4000-a000-000000000002'::uuid, 'Молоко Простоквашино 3,2%', '0,5 л',         0.5, 12,   9,  2),
        ('b1000000-0000-4000-a000-000000000012'::uuid, 'a1000000-0000-4000-a000-000000000002'::uuid, 'Молоко Простоквашино 3,2%', '0,2 л',         0.2,  5,  -3, 11),
        -- Пиво: 0,5 л × 12
        ('b1000000-0000-4000-a000-000000000020'::uuid, 'a1000000-0000-4000-a000-000000000003'::uuid, 'Пиво Жигулёвское',          '0,5 л бутылка', 0.5, 12,   7,  8),
        -- Вода: 5 л × 6, 0,5 л × 24
        ('b1000000-0000-4000-a000-000000000030'::uuid, 'a1000000-0000-4000-a000-000000000004'::uuid, 'Вода Бонаква',              '5 л',           5.0,  6, 180, 15),
        ('b1000000-0000-4000-a000-000000000031'::uuid, 'a1000000-0000-4000-a000-000000000004'::uuid, 'Вода Бонаква',              '0,5 л',         0.5, 24, 120,  5),
        -- Две партии: один объём в упаковке (1 л), одинаковая подпись фасовки, разные сроки годности.
        ('b1000000-0000-4000-a000-000000000040'::uuid, 'a1000000-0000-4000-a000-000000000005'::uuid, 'Сок тест · один литраж', '1 л',           1.0,  5,  45,  1),
        ('b1000000-0000-4000-a000-000000000041'::uuid, 'a1000000-0000-4000-a000-000000000005'::uuid, 'Сок тест · один литраж', '1 л',           1.0,  7, 200,  2)
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, created_at, updated_at
)
SELECT v.id, ctx.org_id, ctx.user_id, v.name, '', 'напитки',
       v.quantity, 'in_stock', v.parent_id, v.variant_label, 'liter', v.volume_per_unit,
       NOW() + (v.expires_in_days || ' days')::interval,
       NOW() - (v.created_in_days_ago || ' days')::interval,
       NOW() - (v.created_in_days_ago || ' days')::interval
  FROM variants v CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

-- 3) Листовые позиции без вариантов: разные measure_unit и сроки.
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organizations o ON o.owner_id = u.id AND o.is_personal = TRUE
     WHERE u.email = 'samsonovartem00@gmail.com'
),
leaves(id, name, description, category_name, quantity, measure_unit, expires_in_days, created_in_days_ago) AS (
    VALUES
        -- Просрочено — красный бейдж в активном складе.
        ('a1000000-0000-4000-a000-000000000010'::uuid, 'Креветки варено-мороженые',  '',           'еда',       3,   'piece',  -5, 30),
        ('a1000000-0000-4000-a000-000000000011'::uuid, 'Сыр Маасдам',                '',           'еда',       4,   'piece',  20,  2),
        -- Длина — qty в метрах.
        ('a1000000-0000-4000-a000-000000000012'::uuid, 'Удлинитель сетевой',         '',           'техника',  15,   'meter', NULL, 1),
        ('a1000000-0000-4000-a000-000000000013'::uuid, 'Тарелки одноразовые',        '',           'посуда',  120,   'piece', NULL, 5),
        ('a1000000-0000-4000-a000-000000000014'::uuid, 'Салфетки бумажные',          '',           'посуда',  200,   'piece', NULL, 2)
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, created_at, updated_at
)
SELECT l.id, ctx.org_id, ctx.user_id, l.name, l.description, l.category_name,
       l.quantity, 'in_stock', NULL, '', l.measure_unit, NULL,
       CASE WHEN l.expires_in_days IS NULL THEN NULL
            ELSE NOW() + (l.expires_in_days || ' days')::interval END,
       NOW() - (l.created_in_days_ago || ' days')::interval,
       NOW() - (l.created_in_days_ago || ' days')::interval
  FROM leaves l CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

-- 4) Архивные позиции — для экрана истории.
-- a) Архивная партия молока 0,2 л (вариант под молоком), причина — expired.
-- b) Списанные конфеты — leaf, причина — usedAtEvent.
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organizations o ON o.owner_id = u.id AND o.is_personal = TRUE
     WHERE u.email = 'samsonovartem00@gmail.com'
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, archive_reason, archived_at,
    parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, created_at, updated_at
)
SELECT * FROM (
    SELECT
        'b1000000-0000-4000-a000-000000000013'::uuid AS id,
        ctx.org_id, ctx.user_id,
        'Молоко Простоквашино 3,2%' AS name, '' AS description, 'напитки' AS category_name,
        4 AS quantity, 'archived'::item_status AS status,
        'expired'::archive_reason AS archive_reason,
        NOW() - INTERVAL '1 day' AS archived_at,
        'a1000000-0000-4000-a000-000000000002'::uuid AS parent_item_id,
        '0,2 л' AS variant_label, 'liter' AS measure_unit, 0.2::double precision AS volume_per_unit,
        NOW() - INTERVAL '5 days' AS expiration_date,
        NOW() - INTERVAL '12 days' AS created_at,
        NOW() - INTERVAL '1 day' AS updated_at
      FROM ctx
    UNION ALL
    SELECT
        'a1000000-0000-4000-a000-000000000020'::uuid,
        ctx.org_id, ctx.user_id,
        'Конфеты Мишка косолапый', '', 'еда',
        4, 'archived'::item_status,
        'usedAtEvent'::archive_reason,
        NOW() - INTERVAL '2 days',
        NULL,
        '', 'piece', NULL,
        NOW() + INTERVAL '40 days',
        NOW() - INTERVAL '9 days',
        NOW() - INTERVAL '2 days'
      FROM ctx
) s
ON CONFLICT (id) DO NOTHING;

-- 5) Картинки. Делаем отдельным блоком: UPDATE по фикс UUID, чтобы можно было
-- прогнать поверх уже залитого сида без пересоздания позиций.
-- Источник: thumb-URL'ы из Wikipedia/Wikimedia Commons (свободные лицензии).
UPDATE items SET image_url = thumb FROM (
    VALUES
        -- Сок Rich (root + 2 варианта)
        ('a1000000-0000-4000-a000-000000000001'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        ('b1000000-0000-4000-a000-000000000001'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        ('b1000000-0000-4000-a000-000000000002'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        -- Молоко (root + 3 in-stock варианта + 1 архивный вариант)
        ('a1000000-0000-4000-a000-000000000002'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Glass_of_Milk_%2833657535532%29.jpg/500px-Glass_of_Milk_%2833657535532%29.jpg'),
        ('b1000000-0000-4000-a000-000000000010'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Glass_of_Milk_%2833657535532%29.jpg/500px-Glass_of_Milk_%2833657535532%29.jpg'),
        ('b1000000-0000-4000-a000-000000000011'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Glass_of_Milk_%2833657535532%29.jpg/500px-Glass_of_Milk_%2833657535532%29.jpg'),
        ('b1000000-0000-4000-a000-000000000012'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Glass_of_Milk_%2833657535532%29.jpg/500px-Glass_of_Milk_%2833657535532%29.jpg'),
        ('b1000000-0000-4000-a000-000000000013'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Glass_of_Milk_%2833657535532%29.jpg/500px-Glass_of_Milk_%2833657535532%29.jpg'),
        -- Пиво (root + 1 вариант)
        ('a1000000-0000-4000-a000-000000000003'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Hacker-Pschorr_Oktoberfest_Girl_Remix.jpg/500px-Hacker-Pschorr_Oktoberfest_Girl_Remix.jpg'),
        ('b1000000-0000-4000-a000-000000000020'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Hacker-Pschorr_Oktoberfest_Girl_Remix.jpg/500px-Hacker-Pschorr_Oktoberfest_Girl_Remix.jpg'),
        -- Вода (root + 2 варианта)
        ('a1000000-0000-4000-a000-000000000004'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/0/02/Stilles_Mineralwasser.jpg'),
        ('b1000000-0000-4000-a000-000000000030'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/0/02/Stilles_Mineralwasser.jpg'),
        ('b1000000-0000-4000-a000-000000000031'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/0/02/Stilles_Mineralwasser.jpg'),
        ('a1000000-0000-4000-a000-000000000005'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        ('b1000000-0000-4000-a000-000000000040'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        ('b1000000-0000-4000-a000-000000000041'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Apfelsaft_im_Glas.jpg/500px-Apfelsaft_im_Glas.jpg'),
        -- Leaf-позиции
        ('a1000000-0000-4000-a000-000000000010'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/Palaemon_serratus_Croazia.jpg/500px-Palaemon_serratus_Croazia.jpg'),
        ('a1000000-0000-4000-a000-000000000011'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Maasdam-cheese.jpg/500px-Maasdam-cheese.jpg'),
        ('a1000000-0000-4000-a000-000000000012'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Extension_cord.JPG/500px-Extension_cord.JPG'),
        ('a1000000-0000-4000-a000-000000000013'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/Cutlery_made_from_Cellulose_Acetate_Biograde.JPG/500px-Cutlery_made_from_Cellulose_Acetate_Biograde.JPG'),
        ('a1000000-0000-4000-a000-000000000014'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Napkin_ring.jpg/500px-Napkin_ring.jpg'),
        -- Архивные конфеты
        ('a1000000-0000-4000-a000-000000000020'::uuid, 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Candy_in_Damascus.jpg/500px-Candy_in_Damascus.jpg')
) AS img(target_id, thumb)
WHERE items.id = img.target_id;

COMMIT;

\echo 'Готово. Вставлены корни с вариантами (в т.ч. «Сок тест · один литраж» — 2×1 л с разными сроками), leaf-позиции и архивные. Картинки проставлены.'
