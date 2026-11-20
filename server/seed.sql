INSERT INTO public.points (location, type, name, status, source, last_verified_at) VALUES
  (ST_MakePoint(30.3616, 59.9265)::geography, 'TOILET',          'ТЦ Галерея',         'ACTIVE', 'USER', now() - interval '2 days'),
  (ST_MakePoint(30.3650, 59.9270)::geography, 'TOILET',          'Парк Победы',        'ACTIVE', 'OSM',  NULL),
  (ST_MakePoint(30.3588, 59.9301)::geography, 'CHANGING_TABLE',  'Кафе «Мама»',        'ACTIVE', 'USER', now() - interval '10 days'),
  (ST_MakePoint(30.3520, 59.9240)::geography, 'BENCH',           NULL,                 'ACTIVE', 'OSM',  NULL),
  (ST_MakePoint(30.3700, 59.9310)::geography, 'DRINKING_WATER',  'Фонтанчик у метро',  'ACTIVE', 'OSM',  NULL);

INSERT INTO public.point_attributes (point_id, attribute)
SELECT id, 'FREE' FROM public.points WHERE name IN ('ТЦ Галерея', 'Парк Победы');

INSERT INTO public.point_attributes (point_id, attribute)
SELECT id, 'BABY_CHANGING' FROM public.points WHERE name = 'Кафе «Мама»';