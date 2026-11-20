--Расширение для географических данных
CREATE EXTENSION IF NOT EXISTS postgis;

--ENUM-типы
CREATE TYPE situation_profile AS ENUM ('DEFAULT', 'WITH_STROLLER', 'WITH_DOG', 'ELDERLY', 'DISABLED');
CREATE TYPE user_role         AS ENUM ('USER', 'MODERATOR', 'ADMIN');
CREATE TYPE point_type        AS ENUM ('TOILET', 'BENCH', 'TRASH_BIN', 'DRINKING_WATER', 'CHANGING_TABLE', 'RAMP');
CREATE TYPE point_status      AS ENUM ('ACTIVE', 'CLOSED', 'OUTDATED', 'UNDER_REVIEW');
CREATE TYPE point_source      AS ENUM ('OSM', 'USER', 'TWOGIS');
CREATE TYPE point_attribute   AS ENUM ('FREE', 'PAID', 'HAS_PAPER', 'BABY_CHANGING', 'WHEELCHAIR_ACCESS', 'IN_SHADE', 'OPEN_NOW');
CREATE TYPE confirm_status    AS ENUM ('WORKS', 'CLOSED', 'DIRTY', 'NO_PAPER', 'BROKEN_RAMP');
CREATE TYPE report_reason     AS ENUM ('SPAM', 'WRONG_LOCATION', 'DUPLICATE', 'OFFENSIVE', 'OTHER');
CREATE TYPE report_status     AS ENUM ('OPEN', 'RESOLVED', 'REJECTED');

--Пользователи (id совпадает с auth.users)
CREATE TABLE public.users (
  id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id         varchar(128) UNIQUE,
  situation_profile situation_profile NOT NULL DEFAULT 'DEFAULT',
  email             varchar(255) UNIQUE,
  phone             varchar(20) UNIQUE,
  role              user_role NOT NULL DEFAULT 'USER',
  is_blocked        boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

--Точки комфорта
CREATE TABLE public.points (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location         geography(Point, 4326) NOT NULL,
  type             point_type NOT NULL,
  status           point_status NOT NULL DEFAULT 'ACTIVE',
  source           point_source NOT NULL DEFAULT 'USER',
  external_id      varchar(100),
  name             varchar(200),
  address          varchar(300),
  created_by       uuid REFERENCES public.users(id) ON DELETE SET NULL,
  last_verified_at timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX points_location_gist ON public.points USING GIST (location);

CREATE UNIQUE INDEX points_source_external_uq ON public.points (source, external_id)
  WHERE external_id IS NOT NULL;

--Атрибуты точки
CREATE TABLE public.point_attributes (
  point_id   uuid NOT NULL REFERENCES public.points(id) ON DELETE CASCADE,
  attribute  point_attribute NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (point_id, attribute)
);

--Подтверждения статуса
CREATE TABLE public.confirmations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  point_id   uuid NOT NULL REFERENCES public.points(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  status     confirm_status NOT NULL,
  comment    varchar(300),
  created_at timestamptz NOT NULL DEFAULT now()
);

--Жалобы
CREATE TABLE public.reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  point_id    uuid NOT NULL REFERENCES public.points(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reason      report_reason NOT NULL,
  comment     varchar(300),
  status      report_status NOT NULL DEFAULT 'OPEN',
  resolved_by uuid REFERENCES public.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

--Фото точек
CREATE TABLE public.point_photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  point_id    uuid NOT NULL REFERENCES public.points(id) ON DELETE CASCADE,
  url         varchar(500) NOT NULL,
  uploaded_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  is_approved boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

--Сохранённые маршруты
CREATE TABLE public.saved_routes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  from_location geography(Point, 4326) NOT NULL,
  to_location   geography(Point, 4326) NOT NULL,
  profile       situation_profile NOT NULL DEFAULT 'DEFAULT',
  polyline      text NOT NULL,
  waypoints     jsonb,
  distance_m    int NOT NULL CHECK (distance_m >= 0),
  duration_min  int NOT NULL CHECK (duration_min >= 0),
  created_at    timestamptz NOT NULL DEFAULT now()
);

--Учёт запросов к LLM (лимит 20 в день)
CREATE TABLE public.llm_usage (
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  day     date NOT NULL DEFAULT current_date,
  used    int  NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

--Профиль создаётся автоматически при регистрации
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, device_id)
  VALUES (NEW.id, NEW.raw_user_meta_data ->> 'device_id')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();