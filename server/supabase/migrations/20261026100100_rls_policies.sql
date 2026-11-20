--Включаем RLS на всех таблицах
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.confirmations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_photos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_routes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_usage        ENABLE ROW LEVEL SECURITY;

--users: только свой профиль
CREATE POLICY users_select_own ON public.users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

--points: читают все, создают авторизованные, правит и удаляет создатель
CREATE POLICY points_select_public ON public.points
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY points_insert_auth ON public.points
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY points_update_owner ON public.points
  FOR UPDATE TO authenticated
  USING (auth.uid() = created_by)
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY points_delete_owner ON public.points
  FOR DELETE TO authenticated
  USING (auth.uid() = created_by);

--point_attributes: только чтение (запись делает сервис)
CREATE POLICY attrs_select_public ON public.point_attributes
  FOR SELECT TO anon, authenticated
  USING (true);

--confirmations: читают все, создаёт авторизованный от своего имени
CREATE POLICY conf_select_public ON public.confirmations
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY conf_insert_auth ON public.confirmations
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

--reports: создавать и видеть только свои
CREATE POLICY reports_insert_auth ON public.reports
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY reports_select_own ON public.reports
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

--point_photos: одобренные видны всем, неодобренные только автору
CREATE POLICY photos_select ON public.point_photos
  FOR SELECT TO anon, authenticated
  USING (is_approved OR auth.uid() = uploaded_by);

--saved_routes: полный доступ только к своим
CREATE POLICY routes_own ON public.saved_routes
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- llm_usage: политик нет, поэтому клиенты доступа не имеют.
-- Работает только service_role, который обходит RLS.