-- Сидер склада организации «cstati» (тусовки в лофтах: бар, свет, звук, танцпол).
-- Привязка к аккаунту samsonovartem00@gmail.com (held_by = этот пользователь).
-- Идемпотентно: фиксированные UUID + ON CONFLICT (id) DO NOTHING.
--
-- Запуск из каталога backend:
--   cat scripts/seed_cstati_org_party.sql | docker compose exec -T postgres psql -U cstati -d cstatiwarehouse
-- или: make seed-cstati-party

\set ON_ERROR_STOP on

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM users u
          JOIN organization_members om ON om.user_id = u.id
          JOIN organizations o ON o.id = om.organization_id
         WHERE u.email = 'samsonovartem00@gmail.com'
           AND o.is_personal = FALSE
           AND lower(trim(o.name)) = 'cstati'
    ) THEN
        RAISE EXCEPTION 'Нужна не-личная организация с именем «cstati» и участник samsonovartem00@gmail.com';
    END IF;
END $$;

BEGIN;

-- Корни с вариантами (напитки в литрах).
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organization_members om ON om.user_id = u.id
      JOIN organizations o ON o.id = om.organization_id
     WHERE u.email = 'samsonovartem00@gmail.com'
       AND o.is_personal = FALSE
       AND lower(trim(o.name)) = 'cstati'
     LIMIT 1
),
roots(id, name, description, category_name, created_at) AS (
    VALUES
        ('c3fa0000-0000-4000-a000-000000000101'::uuid,
         'Моктейли «Лофт» — базовые смеси',
         'Готовые базы для сервиса на баре: три разных профиля вкуса. Хранить охлаждёнными после вскрытия; перед мероприятием проверить кег-соединения и маркировку ТТН.',
         'Напитки и бар',
         NOW() - INTERVAL '4 days'),
        ('c3fa0000-0000-4000-a000-000000000102'::uuid,
         'Вода для бара и сервиса',
         'Питьевая вода для разбавления сиропов, льда и технички. Не использовать для парогенераторов.',
         'Напитки и бар',
         NOW() - INTERVAL '6 days')
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, archive_reason, archived_at,
    parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, image_url, location_address,
    created_at, updated_at
)
SELECT r.id, ctx.org_id, ctx.user_id, r.name, r.description, r.category_name,
       0, 'in_stock', NULL, NULL,
       NULL, '', 'piece', NULL,
       NULL,
       'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Cocktails_at_bar.jpg/800px-Cocktails_at_bar.jpg',
       'Лофт «Графит», барная линия, стеллаж напитков B1',
       r.created_at, r.created_at
  FROM roots r CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

-- Варианты напитков (литры).
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organization_members om ON om.user_id = u.id
      JOIN organizations o ON o.id = om.organization_id
     WHERE u.email = 'samsonovartem00@gmail.com'
       AND o.is_personal = FALSE
       AND lower(trim(o.name)) = 'cstati'
     LIMIT 1
),
variants(id, parent_id, name, variant_label, volume_per_unit, quantity, expires_in_days, created_days_ago, description, location_address, image_url) AS (
    VALUES
        ('c3fa0000-0000-4000-a000-000000000111'::uuid, 'c3fa0000-0000-4000-a000-000000000101'::uuid,
         'Моктейль «Грейпфрут–розмарин»', 'ПЭТ 1 л', 1.0::double precision, 8, 45, 4,
         'Партия для welcome-зоны. После вскрытия — только холодильник +72 ч.',
         'Лофт «Графит», бар, холодильник №2',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Blood_orange_and_rosemary_gin_cocktail.jpg/600px-Blood_orange_and_rosemary_gin_cocktail.jpg'),
        ('c3fa0000-0000-4000-a000-000000000112'::uuid, 'c3fa0000-0000-4000-a000-000000000101'::uuid,
         'Моктейль «Маракуйя–кокос»', 'ПЭТ 1 л', 1.0::double precision, 10, 60, 3,
         'База под слойную подачу на танцполе; перед выдачей взболтать.',
         'Лофт «Графит», бар, холодильник №2',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Pornstar_Martini.jpg/500px-Pornstar_Martini.jpg'),
        ('c3fa0000-0000-4000-a000-000000000113'::uuid, 'c3fa0000-0000-4000-a000-000000000101'::uuid,
         'Моктейль «Цитрус–имбирь»', 'ПЭТ 1 л', 1.0::double precision, 6, 30, 4,
         'Более кислый профиль для второй волны гостей.',
         'Лофт «Графит», бар, нижняя полка',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e6/Moscow_Mule.jpg/500px-Moscow_Mule.jpg'),
        ('c3fa0000-0000-4000-a000-000000000121'::uuid, 'c3fa0000-0000-4000-a000-000000000102'::uuid,
         'Вода минеральная негазированная', '5 л', 5.0::double precision, 4, 400, 6,
         'Крупная упаковка для станций с льдом у бара.',
         'Лофт «Графит», склад за баром, штабелёр H',
         'https://upload.wikimedia.org/wikipedia/commons/0/02/Stilles_Mineralwasser.jpg'),
        ('c3fa0000-0000-4000-a000-000000000122'::uuid, 'c3fa0000-0000-4000-a000-000000000102'::uuid,
         'Вода минеральная негазированная', '1,5 л', 1.5::double precision, 24, 540, 5,
         'Мобильная упаковка для сервиса на зоне программы.',
         'Лофт «Графит», зона программы, контейнер «вода»',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Plastic_water_bottle.jpg/500px-Plastic_water_bottle.jpg')
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, archive_reason, archived_at,
    parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, image_url, location_address,
    created_at, updated_at
)
SELECT v.id, ctx.org_id, ctx.user_id, v.name, v.description, 'Напитки и бар',
       v.quantity, 'in_stock', NULL, NULL,
       v.parent_id, v.variant_label, 'liter', v.volume_per_unit,
       NOW() + (v.expires_in_days || ' days')::interval,
       v.image_url,
       v.location_address,
       NOW() - (v.created_days_ago || ' days')::interval,
       NOW() - (v.created_days_ago || ' days')::interval
  FROM variants v CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

-- Листовые позиции (оборудование и расходники).
WITH ctx AS (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organization_members om ON om.user_id = u.id
      JOIN organizations o ON o.id = om.organization_id
     WHERE u.email = 'samsonovartem00@gmail.com'
       AND o.is_personal = FALSE
       AND lower(trim(o.name)) = 'cstati'
     LIMIT 1
),
leaves(id, name, description, category_name, quantity, measure_unit, volume_per_unit,
       expires_in_days, location_address, image_url, created_days_ago) AS (
    VALUES
        ('c3fa0000-0000-4000-a000-000000000201'::uuid,
         'Дым-машина Antari Z-350',
         'Жидкий туман, DMX. Заправка: жидкость быстрого рассеивания. Перед включением проверить расстояние до датчиков пожарной сигнализации.',
         'Атмосфера и спецэффекты',
         1, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», танцпол, левый трасс под лазером',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Fog_machine_smoke.jpg/640px-Fog_machine_smoke.jpg',
         9),
        ('c3fa0000-0000-4000-a000-000000000202'::uuid,
         'Сабвуфер активный 18" (стэк)',
         'Пара для фронт-фила танцпола; настройка HP/LP согласно замерам SPL не менее чем за 2 ч до открытия.',
         'Звук',
         2, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», сцена, левый фланг',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Subwoofer.jpg/600px-Subwoofer.jpg',
         14),
        ('c3fa0000-0000-4000-a000-000000000203'::uuid,
         'Комплект LED PAR wash RGB (приборы)',
         'Шесть приборов в кейсе + крепления на трубу 48 мм. Для равномерной заливки танцпола и боковых арок.',
         'Свет',
         6, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», ферма над танцполом, короб «PAR»',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/LED_stage_lighting.jpg/640px-LED_stage_lighting.jpg',
         11),
        ('c3fa0000-0000-4000-a000-000000000204'::uuid,
         'Контроллер DMX + резервный приёмник',
         'Основной пульт программы света и запасной приёмник на случай RF-помех от Wi‑Fi лофта.',
         'Свет',
         1, 'package', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», техничка света, стол FOH',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/DMX_console.jpg/640px-DMX_console.jpg',
         7),
        ('c3fa0000-0000-4000-a000-000000000205'::uuid,
         'Силовой кабель КГтп 3×2,5 мм² (бухта)',
         'Запас для питания стэков и дым-машин по сертифицированной разводке; не использовать для бытовых удлинителей гостей.',
         'Электрика и трассировка',
         50, 'meter', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», кабель-кан за барабанной установкой',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Extension_cord.JPG/640px-Extension_cord.JPG',
         3),
        ('c3fa0000-0000-4000-a000-000000000206'::uuid,
         'Гобо-проектор с диском логотипа cstati',
         'Фокус по логотипу на входной арке; запасная лампа и монтажный кронштейн в нижнем отсеке кейса.',
         'Свет',
         1, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», входная группа, стойка промо',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/Gobo_projector.jpg/600px-Gobo_projector.jpg',
         12),
        ('c3fa0000-0000-4000-a000-000000000207'::uuid,
         'Разделитель VIP (стойки + канат)',
         'Бархатный канат тёмно-изумрудный, 8 стоек; быстрая сборка без сверления пола лофта.',
         'Декор и навигация',
         1, 'package', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», зона лаунж у барной стойки',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Velvet_rope_barrier.jpg/640px-Velvet_rope_barrier.jpg',
         5),
        ('c3fa0000-0000-4000-a000-000000000208'::uuid,
         'Ролл-ап баннер «LINE UP · tonight»',
         'Двусторонняя печать, пружина проверена; хранить в тубусе вертикально.',
         'Печать и навигация',
         2, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», вход, стойка аккредитации',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Roll-up_banner.jpg/500px-Roll-up_banner.jpg',
         2),
        ('c3fa0000-0000-4000-a000-000000000209'::uuid,
         'Стаканы пластиковые 200 мл (короба)',
         '100 шт × 12 коробов; под коктейльную подачу и shot-line на баре.',
         'Расходники',
         12, 'package', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», склад за баром, полка одноразки',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/Cutlery_made_from_Cellulose_Acetate_Biograde.JPG/640px-Cutlery_made_from_Cellulose_Acetate_Biograde.JPG',
         4),
        ('c3fa0000-0000-4000-a000-000000000210'::uuid,
         'Подстаканники с логотипом (упаковки)',
         'Крафт + ламинация; пачки по 500 шт; выдавать промо на входе.',
         'Расходники',
         2, 'package', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», промо-стол у гардероба',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Napkin_ring.jpg/500px-Napkin_ring.jpg',
         6),
        ('c3fa0000-0000-4000-a000-000000000211'::uuid,
         'Барная стойка складная 2 м (столешница дуб)',
         'Установка по уровню; комплект стяжек и противоскользящие подкладки в комплекте.',
         'Мебель и сцена',
         1, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», барная зона, центральная линия',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Portable_bar_counter.jpg/640px-Portable_bar_counter.jpg',
         8),
        ('c3fa0000-0000-4000-a000-000000000212'::uuid,
         'Напольный поддон под DJ (антивибро)',
         'Размер под контроллер Denon/Mixer класса клуб; не ставить напитки.',
         'Мебель и сцена',
         1, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», сцена, позиция DJ',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/DJ_stage_setup.jpg/640px-DJ_stage_setup.jpg',
         10),
        ('c3fa0000-0000-4000-a000-000000000213'::uuid,
         'Радиосистема РШ (2 ручных передатчика + приёмник)',
         'Частота лицензируемая; запасные батарейки AA в кейсе; антенны разворачивать под углом 45°.',
         'Звук',
         1, 'package', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», сцена, рековая стойка',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Shure_wireless_microphone.jpg/600px-Shure_wireless_microphone.jpg',
         13),
        ('c3fa0000-0000-4000-a000-000000000214'::uuid,
         'Стробоскоп LED (не ксенон)',
         'Только для коротких сетов; объявлять фоточувствительным гостям.',
         'Свет',
         2, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», танцпол, центральная ферма',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Strobe_light_effect.jpg/640px-Strobe_light_effect.jpg',
         11),
        ('c3fa0000-0000-4000-a000-000000000215'::uuid,
         'Удлинитель на катушке 25 м (с УЗО)',
         'Для лёгкой периферии FOH; не нагружать тепловыми пушками.',
         'Электрика и трассировка',
         25, 'meter', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», зона программы, подспудник',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Extension_cord.JPG/640px-Extension_cord.JPG',
         3),
        ('c3fa0000-0000-4000-a000-000000000216'::uuid,
         'Головка вращающаяся spot LED (moving head)',
         'Режимы beam/prism; калибровка после транспортировки обязательна.',
         'Свет',
         2, 'piece', NULL::double precision,
         NULL::integer,
         'Лофт «Графит», ферма центр, подвес «moving»',
         'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Moving_head_light.jpg/640px-Moving_head_light.jpg',
         15)
)
INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, archive_reason, archived_at,
    parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, image_url, location_address,
    created_at, updated_at
)
SELECT l.id, ctx.org_id, ctx.user_id, l.name, l.description, l.category_name,
       l.quantity, 'in_stock', NULL, NULL,
       NULL, '', l.measure_unit, l.volume_per_unit,
       CASE WHEN l.expires_in_days IS NULL THEN NULL
            ELSE NOW() + (l.expires_in_days || ' days')::interval END,
       l.image_url,
       l.location_address,
       NOW() - (l.created_days_ago || ' days')::interval,
       NOW() - (l.created_days_ago || ' days')::interval
  FROM leaves l CROSS JOIN ctx
ON CONFLICT (id) DO NOTHING;

INSERT INTO items (
    id, organization_id, held_by_user_id, name, description, category_name,
    quantity, status, archive_reason, archived_at,
    parent_item_id, variant_label, measure_unit, volume_per_unit,
    expiration_date, image_url, location_address,
    created_at, updated_at
)
SELECT l.id, ctx.org_id, ctx.user_id, l.name, l.description, l.category_name,
       l.quantity, 'in_stock', NULL, NULL,
       NULL, '', l.measure_unit, NULL::double precision,
       NULL, NULL, l.location_address,
       NOW() - (l.created_days_ago || ' days')::interval,
       NOW() - (l.created_days_ago || ' days')::interval
  FROM (
    VALUES
        ('c3fa0000-0000-4000-a000-000000000217'::uuid,
         'Барный стул металлический (чёрный)',
         '',
         'Мебель и сцена',
         24, 'piece'::text,
         'Лофт «Графит», склад мебели, стеллаж М',
         1),
        ('c3fa0000-0000-4000-a000-000000000218'::uuid,
         'Салфетки бумажные белые 33×33 см',
         '',
         'Расходники',
         800, 'piece'::text,
         'Лофт «Графит», сервисная, полка расходников',
         2)
  ) AS l(id, name, description, category_name, quantity, measure_unit, location_address, created_days_ago)
 CROSS JOIN (
    SELECT u.id AS user_id, o.id AS org_id
      FROM users u
      JOIN organization_members om ON om.user_id = u.id
      JOIN organizations o ON o.id = om.organization_id
     WHERE u.email = 'samsonovartem00@gmail.com'
       AND o.is_personal = FALSE
       AND lower(trim(o.name)) = 'cstati'
     LIMIT 1
 ) ctx
ON CONFLICT (id) DO NOTHING;

COMMIT;

\echo 'Готово: склад организации cstati пополнен (напитки с вариантами + оборудование лофт-тусовки). Позиции 217–218 без описания и без фото.'
