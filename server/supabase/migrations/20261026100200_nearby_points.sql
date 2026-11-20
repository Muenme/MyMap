CREATE OR REPLACE FUNCTION public.nearby_points(
  p_lat                  double precision,
  p_lng                  double precision,
  p_radius_m             int DEFAULT 500,
  p_types                point_type[] DEFAULT NULL,
  p_verified_within_days int DEFAULT NULL
)
RETURNS TABLE (
  point_id         uuid,
  point_type       point_type,
  point_name       varchar,
  lat              double precision,
  lng              double precision,
  distance_m       double precision,
  last_verified_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id,
    p.type,
    p.name,
    ST_Y(p.location::geometry),
    ST_X(p.location::geometry),
    ST_Distance(p.location, ST_MakePoint(p_lng, p_lat)::geography),
    p.last_verified_at
  FROM public.points p
  WHERE p.status = 'ACTIVE'
    AND ST_DWithin(p.location, ST_MakePoint(p_lng, p_lat)::geography, p_radius_m)
    AND (p_types IS NULL OR p.type = ANY (p_types))
    AND (p_verified_within_days IS NULL
         OR p.last_verified_at >= now() - make_interval(days => p_verified_within_days))
  ORDER BY 6
  LIMIT 100;
$$;