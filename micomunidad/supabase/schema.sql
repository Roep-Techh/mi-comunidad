-- ============================================================================
--  MiComunidad · Esquema de base de datos  (Supabase · PostgreSQL)
-- ============================================================================
--  CÓMO USARLO:
--   1. Crea tu proyecto en https://supabase.com (gratis)
--   2. SQL Editor → New query → pega ESTE ARCHIVO COMPLETO → Run
--   3. Authentication → Sign In / Providers → activa "Anonymous sign-ins"
--   4. Authentication → Users → Add user (correo + contraseña) = TI como admin
--   5. SQL Editor → ejecuta el bloque "CREAR TU USUARIO ADMIN" (descoméntalo)
--   6. Storage: el bucket "fotos" se crea solo con este script
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. PUEBLOS  (multi-inquilino: TODO lleva pueblo_id)
-- ---------------------------------------------------------------------------
create table if not exists pueblos (
  id     text primary key,
  nombre text not null,
  icono  text not null default '🏘️',
  activo boolean not null default true
);

insert into pueblos (id, nombre, icono) values
  ('p1','San Miguel','🏘️'),
  ('p2','Santa Rosa','🌾'),
  ('p3','La Esperanza','🌄')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. PERFILES (vendedores, instituciones, admin)
--    id = uid de Supabase Auth (sesión anónima del dispositivo)
-- ---------------------------------------------------------------------------
create table if not exists perfiles (
  id         uuid primary key references auth.users(id) on delete cascade on update cascade,
  pueblo_id  text not null references pueblos(id),
  rol        text not null default 'vendedor'
             check (rol in ('vendedor','auspiciador','admin')),
  nombre     text not null check (length(trim(nombre)) >= 3),
  celular    text unique check (celular is null or celular ~ '^[0-9]{10}$'),
  pin_hash   text,
  negocio    text,
  avatar     text not null default '👤',
  estado     text not null default 'pendiente'
             check (estado in ('pendiente','aprobado','rechazado')),
  ventas     int not null default 0,
  estrellas  numeric not null default 5.0 check (estrellas between 0 and 5),
  resenas    int not null default 0,
  verificado boolean not null default false,
  creado     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. PUBLICACIONES (ventas de vendedores aprobados)
-- ---------------------------------------------------------------------------
create table if not exists publicaciones (
  id          bigserial primary key,
  pueblo_id   text not null references pueblos(id),
  perfil_id   uuid references perfiles(id) on delete cascade on update cascade,
  titulo      text not null check (length(trim(titulo)) >= 4),
  precio      text,
  categoria   text not null default '📦 Productos',
  descripcion text,
  emoji       text not null default '🛒',
  fotos       text[] not null default '{}',
  destacado   boolean not null default false,
  dest_dias   int not null default 0,
  estado      text not null default 'pendiente'
              check (estado in ('pendiente','aprobado','rechazado')),
  creado      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. AVISOS (cualquiera, sin cuenta: nombre + celular + revisión)
--    pendiente  = espera verificación (5 días o más)
--    revisando  = ya se publicó solo (1 día) y va revisión de spam
--    aprobado   = verificado       rechazado = retirado
-- ---------------------------------------------------------------------------
create table if not exists avisos (
  id          bigserial primary key,
  pueblo_id   text not null references pueblos(id),
  nombre      text not null check (length(trim(nombre)) >= 3),
  celular     text not null check (celular ~ '^[0-9]{10}$'),
  ic          text not null default '📢',
  tipo        text not null default 'Aviso',
  titulo      text not null check (length(trim(titulo)) >= 5),
  descripcion text,
  fotos       text[] not null default '{}',
  dias        int not null check (dias between 1 and 120),
  destacado   boolean not null default false,
  estado      text not null default 'pendiente'
              check (estado in ('pendiente','revisando','aprobado','rechazado')),
  creado      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. PATROCINADORES y REPORTES
-- ---------------------------------------------------------------------------
create table if not exists patrocinadores (
  id         bigserial primary key,
  pueblo_id  text not null references pueblos(id),
  nivel      text not null check (nivel in ('super','local')),
  ic         text not null default '🏪',
  nombre     text not null,
  categoria  text,
  tag        text,
  precio_num int not null default 100,
  estado     text not null default 'AL DÍA'
             check (estado in ('AL DÍA','POR RENOVAR','VENCIDO')),
  vistas     int not null default 0,
  orden      int not null default 0,
  creado     timestamptz not null default now()
);

create table if not exists reportes (
  id        bigserial primary key,
  pueblo_id text not null references pueblos(id),
  tipo      text not null check (tipo in ('publicacion','aviso')),
  ref_id    bigint not null,
  motivo    text,
  estado    text not null default 'abierto'
            check (estado in ('abierto','cerrado')),
  creado    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. CONTROL DE INTENTOS DE PIN (5 fallos = 15 min de bloqueo)
-- ---------------------------------------------------------------------------
create table if not exists intentos_pin (
  celular         text primary key,
  intentos        int not null default 0,
  bloqueado_hasta timestamptz,
  ultimo          timestamptz not null default now()
);
alter table intentos_pin enable row level security;  -- nadie lo toca a mano

-- ---------------------------------------------------------------------------
-- 7. ÍNDICES
-- ---------------------------------------------------------------------------
create index if not exists idx_pub_pueblo on publicaciones (pueblo_id, estado, creado desc);
create index if not exists idx_pub_perfil on publicaciones (perfil_id);
create index if not exists idx_av_pueblo  on avisos (pueblo_id, estado, creado desc);
create index if not exists idx_av_cel     on avisos (celular, creado desc);
create index if not exists idx_pat_pueblo on patrocinadores (pueblo_id, nivel);

-- ===========================================================================
--  FUNCIONES
-- ===========================================================================

-- Hash del PIN con bcrypt (sal aleatoria; imposible de adivinar aunque alguien
-- vea la tabla).  Se guarda en perfiles.pin_hash y NO es legible desde la app.
create or replace function hash_pin(p_celular text, p_pin text)
returns text language sql as $$
  select crypt(p_celular || '|' || p_pin, gen_salt('bf', 10));
$$;

create or replace function es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfiles
                 where id = auth.uid() and rol = 'admin' and estado = 'aprobado');
$$;

-- ---------------------------------------------------------------------------
-- REGISTRO de vendedor/institución: celular + PIN de 6 dígitos.
-- Devuelve ok/mensaje (nunca lanza excepción) para que el conteo de
-- intentos no se revierta con un rollback.
-- ---------------------------------------------------------------------------
create or replace function crear_perfil(
  p_nombre text, p_celular text, p_pin text,
  p_negocio text default null, p_pueblo_id text default 'p1',
  p_rol text default 'vendedor'
)
returns table (ok boolean, mensaje text, id uuid, nombre text, negocio text,
               rol text, pueblo_id text, estado text)
language plpgsql security definer set search_path = public as $$
declare
  v_id      uuid;
  v_nombre  text;
  v_negocio text;
  v_rol     text;
  v_pueblo  text;
  v_estado  text;
begin
  if auth.uid() is null then
    return query select false, 'Sesión no iniciada.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if p_nombre is null or length(trim(p_nombre)) < 3 then
    return query select false, 'Escribe tu nombre completo (mínimo 3 letras).', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if p_celular is null or p_celular !~ '^[0-9]{10}$' then
    return query select false, 'El celular debe tener 10 dígitos.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return query select false, 'El PIN debe tener 6 dígitos.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if exists (select 1 from perfiles where celular = p_celular) then
    return query select false, 'Ese celular ya tiene perfil. Entra con tu PIN.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if exists (select 1 from perfiles where id = auth.uid()) then
    return query select false, 'Este dispositivo ya tiene perfil. Entra con tu PIN.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;
  if not exists (select 1 from pueblos where id = p_pueblo_id) then
    return query select false, 'Comunidad no válida.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;

  insert into perfiles (id, pueblo_id, rol, nombre, celular, pin_hash, negocio, estado)
  values (auth.uid(), p_pueblo_id,
          case when p_rol in ('vendedor','auspiciador') then p_rol else 'vendedor' end,
          trim(p_nombre), p_celular, hash_pin(p_celular, p_pin),
          nullif(trim(coalesce(p_negocio,'')),''), 'pendiente')
  returning id, nombre, negocio, rol, pueblo_id, estado
    into v_id, v_nombre, v_negocio, v_rol, v_pueblo, v_estado;

  return query select true, 'Registro enviado. Un administrador lo aprueba (máx. 24 h).',
                      v_id, v_nombre, v_negocio, v_rol, v_pueblo, v_estado;
  return;
end;
$$;

-- ---------------------------------------------------------------------------
-- LOGIN de vendedor: celular + PIN → vincula el perfil a este dispositivo.
-- ---------------------------------------------------------------------------
create or replace function reclamar_perfil(p_celular text, p_pin text)
returns table (ok boolean, mensaje text, id uuid, nombre text, negocio text,
               rol text, pueblo_id text, estado text)
language plpgsql security definer set search_path = public as $$
declare
  v   perfiles%rowtype;
  n   int := 0;
  blk timestamptz;
begin
  if auth.uid() is null then
    return query select false, 'Sesión no iniciada.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;

  select coalesce(intentos,0), bloqueado_hasta into n, blk
    from intentos_pin where celular = p_celular;
  if n is null then n := 0; end if;
  if blk is not null and now() < blk then
    return query select false, 'Demasiados intentos. Vuelve en 15 minutos.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;

  select * into v from perfiles where celular = p_celular;

  if v.id is null or v.pin_hash is null or v.pin_hash <> crypt(coalesce(p_pin,''), v.pin_hash) then
    insert into intentos_pin (celular, intentos, ultimo)
    values (p_celular, 1, now())
    on conflict (celular) do update
      set intentos = intentos_pin.intentos + 1,
          ultimo   = now(),
          bloqueado_hasta = case when intentos_pin.intentos + 1 >= 5
                                 then now() + interval '15 minutes'
                                 else intentos_pin.bloqueado_hasta end
    returning intentos into n;
    if n >= 5 then
      return query select false, '5 intentos fallidos: bloqueado 15 minutos.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    else
      return query select false, 'Celular o PIN incorrecto.', null::uuid, null::text, null::text, null::text, null::text, null::text;
    end if;
    return;
  end if;

  delete from intentos_pin where celular = p_celular;

  if v.id is distinct from auth.uid() then
    if exists (select 1 from perfiles where id = auth.uid()) then
      return query select false, 'Este dispositivo ya tiene otro perfil.', null::uuid, null::text, null::text, null::text, null::text, null::text;
      return;
    end if;
    update perfiles set id = auth.uid() where celular = p_celular;
    v.id := auth.uid();
  end if;

  return query select true, '¡Hola de nuevo, ' || v.nombre || '!', v.id, v.nombre, v.negocio, v.rol, v.pueblo_id, v.estado;
  return;
end;
$$;

-- ---------------------------------------------------------------------------
-- ENVÍO DE AVISO (lo hace cualquiera, sin cuenta).  Reglas:
--   · 1 día sin destacar  → estado 'revisando' (sale ya, revisión posterior)
--   · 5 días o más        → estado 'pendiente' (espera verificación)
--   · destacado           → siempre 'pendiente' (hay que cobrar $10)
-- ---------------------------------------------------------------------------
create or replace function enviar_aviso(
  p_pueblo_id text, p_nombre text, p_celular text, p_titulo text,
  p_descripcion text default null, p_dias int default 7,
  p_ic text default '📢', p_tipo text default 'Aviso',
  p_destacado boolean default false, p_fotos text[] default '{}'
)
returns table (ok boolean, mensaje text, id bigint, estado text)
language plpgsql security definer set search_path = public as $$
declare
  v_estado text;
  v_id bigint;
  n int;
begin
  if p_nombre is null or length(trim(p_nombre)) < 3 then
    return query select false, 'Escribe quién publica (mínimo 3 letras).', null::bigint, null::text; return;
  end if;
  if p_celular is null or p_celular !~ '^[0-9]{10}$' then
    return query select false, 'El celular debe tener 10 dígitos.', null::bigint, null::text; return;
  end if;
  if p_titulo is null or length(trim(p_titulo)) < 5 then
    return query select false, 'El título debe tener al menos 5 letras.', null::bigint, null::text; return;
  end if;
  if p_dias is null or p_dias < 1 or p_dias > 120 then
    return query select false, 'La duración debe ser de 1 a 120 días.', null::bigint, null::text; return;
  end if;

  -- anti-spam: máximo 3 avisos por celular en 24 horas
  select count(*) into n from avisos
   where celular = p_celular and creado > now() - interval '24 hours';
  if n >= 3 then
    return query select false, 'Máximo 3 avisos por celular en 24 horas.', null::bigint, null::text; return;
  end if;

  v_estado := case when p_dias = 1 and not p_destacado then 'revisando' else 'pendiente' end;

  insert into avisos (pueblo_id, nombre, celular, titulo, descripcion, dias, ic, tipo,
                      destacado, fotos, estado)
  values (p_pueblo_id, trim(p_nombre), p_celular, trim(p_titulo), p_descripcion,
          p_dias, p_ic, p_tipo, p_destacado, coalesce(p_fotos,'{}'), v_estado)
  returning id into v_id;

  if v_estado = 'revisando' then
    return query select true, 'Publicado ya mismo — lo estamos revisando por spam.', v_id, v_estado;
  else
    return query select true, 'Recibido. Lo verificamos en máximo 20 minutos.', v_id, v_estado;
  end if;
  return;
end;
$$;

-- ---------------------------------------------------------------------------
-- PROTECCIÓN DE CAMPOS SENSIBLES
-- Aunque una política RLS lo permita, un vendedor jamás debe poder:
--   · aprobarse a sí mismo (estado)      · cambiar su rol a 'admin'
--   · ponerse 'destacado' sin pagar      · mover su publicación a otro pueblo
-- ---------------------------------------------------------------------------
create or replace function proteger_fila() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if es_admin() then return new; end if;

  if tg_table_name = 'perfiles' then
    new.rol     := old.rol;
    new.estado  := old.estado;
    if new.id is distinct from auth.uid() then new.id := old.id; end if;

  elsif tg_table_name = 'publicaciones' then
    new.destacado := old.destacado;
    new.dest_dias := old.dest_dias;
    new.pueblo_id := old.pueblo_id;

  elsif tg_table_name = 'avisos' then
    new.destacado := old.destacado;
    new.estado    := old.estado;
    new.creado    := old.creado;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_perfiles_proteg on perfiles;
create trigger trg_perfiles_proteg before update on perfiles
  for each row execute function proteger_fila();

drop trigger if exists trg_pub_proteg on publicaciones;
create trigger trg_pub_proteg before update on publicaciones
  for each row execute function proteger_fila();

drop trigger if exists trg_avisos_proteg on avisos;
create trigger trg_avisos_proteg before update on avisos
  for each row execute function proteger_fila();

-- ===========================================================================
--  SEGURIDAD (RLS)
-- ===========================================================================
alter table pueblos         enable row level security;
alter table perfiles        enable row level security;
alter table publicaciones   enable row level security;
alter table avisos          enable row level security;
alter table patrocinadores  enable row level security;
alter table reportes        enable row level security;

-- ---- pueblos
drop policy if exists "pueblos lectura" on pueblos;
create policy "pueblos lectura" on pueblos for select using (activo);
drop policy if exists "pueblos admin" on pueblos;
create policy "pueblos admin" on pueblos for update using (es_admin());
drop policy if exists "pueblos admin ins" on pueblos;
create policy "pueblos admin ins" on pueblos for insert with check (es_admin());

-- ---- perfiles
drop policy if exists "perfiles lectura" on perfiles;
create policy "perfiles lectura" on perfiles for select
  using (estado = 'aprobado' or id = auth.uid() or es_admin());
drop policy if exists "perfiles ins" on perfiles;
create policy "perfiles ins" on perfiles for insert
  with check (id = auth.uid() and estado = 'pendiente'
              and rol in ('vendedor','auspiciador'));
drop policy if exists "perfiles upd" on perfiles;
create policy "perfiles upd" on perfiles for update
  using (es_admin() or id = auth.uid())
  with check (es_admin() or (id = auth.uid() and estado in ('pendiente','aprobado')));
drop policy if exists "perfiles del" on perfiles;
create policy "perfiles del" on perfiles for delete using (es_admin());

-- El hash del PIN jamás sale por la API (el resto de los datos sí)
revoke select on perfiles from anon, authenticated;
grant select (id, pueblo_id, rol, nombre, celular, negocio, avatar, estado,
              ventas, estrellas, resenas, verificado, creado)
   on perfiles to anon, authenticated;

-- ---- publicaciones
drop policy if exists "pub lectura" on publicaciones;
create policy "pub lectura" on publicaciones for select
  using (estado = 'aprobado' or perfil_id = auth.uid() or es_admin());
drop policy if exists "pub ins" on publicaciones;
create policy "pub ins" on publicaciones for insert
  with check (estado = 'pendiente'
              and perfil_id = auth.uid()
              and exists (select 1 from perfiles p
                          where p.id = auth.uid()
                            and p.estado = 'aprobado'
                            and p.rol in ('vendedor','auspiciador')));
drop policy if exists "pub upd" on publicaciones;
create policy "pub upd" on publicaciones for update
  using (es_admin() or perfil_id = auth.uid())
  with check (es_admin() or (perfil_id = auth.uid() and estado = 'pendiente'));
drop policy if exists "pub del" on publicaciones;
create policy "pub del" on publicaciones for delete using (es_admin() or perfil_id = auth.uid());

-- ---- avisos
drop policy if exists "aviso lectura" on avisos;
create policy "aviso lectura" on avisos for select
  using (estado in ('aprobado','revisando') or es_admin());
drop policy if exists "aviso ins" on avisos;
create policy "aviso ins" on avisos for insert
  with check (estado in ('pendiente','revisando')
              and dias between 1 and 120
              and celular ~ '^[0-9]{10}$'
              and length(trim(nombre)) >= 3
              and length(trim(titulo)) >= 5
              and (select count(*) from avisos a
                    where a.celular = avisos.celular
                      and a.creado > now() - interval '24 hours') < 3);
drop policy if exists "aviso upd" on avisos;
create policy "aviso upd" on avisos for update using (es_admin()) with check (es_admin());
drop policy if exists "aviso del" on avisos;
create policy "aviso del" on avisos for delete using (es_admin());

-- ---- patrocinadores
drop policy if exists "pat lectura" on patrocinadores;
create policy "pat lectura" on patrocinadores for select using (true);
drop policy if exists "pat admin" on patrocinadores;
create policy "pat admin" on patrocinadores for insert with check (es_admin());
drop policy if exists "pat admin upd" on patrocinadores;
create policy "pat admin upd" on patrocinadores for update using (es_admin());
drop policy if exists "pat admin del" on patrocinadores;
create policy "pat admin del" on patrocinadores for delete using (es_admin());

-- ---- reportes (cualquiera puede reportar, solo admin los ve)
drop policy if exists "rep ins" on reportes;
create policy "rep ins" on reportes for insert with check (estado = 'abierto');
drop policy if exists "rep admin" on reportes;
create policy "rep admin" on reportes for select using (es_admin());
drop policy if exists "rep admin upd" on reportes;
create policy "rep admin upd" on reportes for update using (es_admin());

-- ===========================================================================
--  STORAGE: bucket público de fotos (WebP comprimido en el navegador)
-- ===========================================================================
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do nothing;

drop policy if exists "fotos lectura" on storage.objects;
create policy "fotos lectura" on storage.objects
  for select using (bucket_id = 'fotos');

drop policy if exists "fotos subir" on storage.objects;
create policy "fotos subir" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'fotos'
              and storage.extension(name) in ('webp','jpg','jpeg','png'));

drop policy if exists "fotos borrar" on storage.objects;
create policy "fotos borrar" on storage.objects
  for delete to authenticated using (bucket_id = 'fotos' and owner = auth.uid());

-- ===========================================================================
--  CREAR TU USUARIO ADMIN  (descoménta y cambia el correo)
-- ===========================================================================
--  Paso 1: Supabase → Authentication → Users → "Add user"
--          (correo y contraseña, marca "Auto Confirm User")
--  Paso 2: ejecuta esto en SQL Editor con ese correo:
--
-- insert into perfiles (id, pueblo_id, rol, nombre, celular, estado, verificado)
-- select u.id, 'p1', 'admin', 'Administrador', null, 'aprobado', true
--   from auth.users u
--  where u.email = 'tu@correo.com'
-- on conflict (id) do nothing;
--
-- El panel de administración se entra con ese correo y contraseña.
