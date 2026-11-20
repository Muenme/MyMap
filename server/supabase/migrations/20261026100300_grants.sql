-- Публичное чтение
GRANT SELECT ON public.points, public.point_attributes,
               public.confirmations, public.point_photos
  TO anon, authenticated;

-- Профиль: читать и обновлять (строки ограничивает RLS)
GRANT SELECT, UPDATE ON public.users TO authenticated;

-- Точки: создание, правка и удаление (строки ограничивает RLS)
GRANT INSERT, UPDATE, DELETE ON public.points TO authenticated;

-- Подтверждения и жалобы
GRANT INSERT ON public.confirmations TO authenticated;
GRANT INSERT, SELECT ON public.reports TO authenticated;

-- Маршруты: полный доступ к своим строкам (RLS)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_routes TO authenticated;

-- Поиск точек доступен всем
GRANT EXECUTE ON FUNCTION public.nearby_points(
  double precision, double precision, int, point_type[], int
) TO anon, authenticated;

-- llm_usage намеренно без прав для anon и authenticated