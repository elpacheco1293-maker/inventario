-- NEXOCORP · Control de inventario por bodega
-- Pegar completo en Supabase > SQL Editor > Run
create extension if not exists pgcrypto with schema extensions;

create table if not exists bodegas(
  id text primary key,
  nombre text, direccion text, logo_url text,
  clave_hash text not null,
  done boolean not null default false, done_at timestamptz);
create table if not exists items(
  id bigserial primary key,
  bodega_id text not null references bodegas(id) on delete cascade,
  codigo text not null, descripcion text,
  sistema numeric not null, fisico numeric,
  agregado boolean not null default false);
alter table items add column if not exists agregado boolean not null default false;
create index if not exists items_bodega_idx on items(bodega_id);

-- Seguridad: nadie anónimo puede leer ni escribir tablas directamente.
alter table bodegas enable row level security;
alter table items enable row level security;
drop policy if exists admin_bodegas on bodegas; drop policy if exists admin_items on items;
create policy admin_bodegas on bodegas for all to authenticated using (true) with check (true);
create policy admin_items on items for all to authenticated using (true) with check (true);

-- Login de bodega: devuelve solo SU bodega y sus ítems
create or replace function bodega_login(p_id text, p_clave text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare b bodegas;
begin
  select * into b from bodegas where id = upper(trim(p_id)) and clave_hash = crypt(upper(trim(p_clave)), clave_hash);
  if not found then raise exception 'credenciales'; end if;
  return json_build_object('id',b.id,'nombre',b.nombre,'direccion',b.direccion,'logo_url',b.logo_url,
    'done',b.done,'done_at',b.done_at,
    'items',(select coalesce(json_agg(json_build_object('id',i.id,'codigo',i.codigo,'descripcion',i.descripcion,'sistema',i.sistema,'fisico',i.fisico) order by i.id),'[]'::json) from items i where i.bodega_id=b.id));
end $$;

-- Guardar físico (una sola vez). p_extra = sobrantes que no estaban en la lista (sistema = 0)
drop function if exists bodega_guardar(text,text,jsonb);
create or replace function bodega_guardar(p_id text, p_clave text, p_vals jsonb, p_extra jsonb default '[]'::jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare b bodegas;
begin
  select * into b from bodegas where id = upper(trim(p_id)) and clave_hash = crypt(upper(trim(p_clave)), clave_hash);
  if not found then raise exception 'credenciales'; end if;
  if b.done then raise exception 'ya_enviado'; end if;
  update items i set fisico = (v->>'fisico')::numeric
    from jsonb_array_elements(p_vals) v where i.id = (v->>'id')::bigint and i.bodega_id = b.id;
  if exists(select 1 from items where bodega_id = b.id and fisico is null) then raise exception 'incompleto'; end if;
  insert into items(bodega_id, codigo, descripcion, sistema, fisico, agregado)
    select b.id, trim(e->>'codigo'), e->>'descripcion', 0, (e->>'fisico')::numeric, true
    from jsonb_array_elements(coalesce(p_extra,'[]'::jsonb)) e
    where coalesce(trim(e->>'codigo'),'') <> ''
      and not exists(select 1 from items x where x.bodega_id = b.id and x.codigo = trim(e->>'codigo'));
  update bodegas set done = true, done_at = now() where id = b.id;
end $$;

-- Catálogo de códigos/descripciones (sin cantidades) para autocompletar sobrantes
create or replace function bodega_catalogo(p_id text, p_clave text) returns table(codigo text, descripcion text)
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists(select 1 from bodegas where id = upper(trim(p_id)) and clave_hash = crypt(upper(trim(p_clave)), clave_hash)) then
    raise exception 'credenciales'; end if;
  return query select distinct on (i.codigo) i.codigo, i.descripcion from items i order by i.codigo;
end $$;

-- Carga del administrador
create or replace function admin_cargar(p_rows jsonb) returns int
language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  if auth.role() <> 'authenticated' then raise exception 'no autorizado'; end if;
  insert into bodegas(id, clave_hash)
    select b, crypt(coalesce(c, b), gen_salt('bf')) from (
      select upper(trim(r->>'bodega')) b, max(nullif(upper(trim(r->>'clave')),'')) c
      from jsonb_array_elements(p_rows) r group by 1) g where b <> ''
    on conflict (id) do nothing;
  update bodegas set done=false, done_at=null
    where id in (select upper(trim(r->>'bodega')) from jsonb_array_elements(p_rows) r);
  update bodegas x set clave_hash = crypt(g.c, gen_salt('bf')) from (
      select upper(trim(r->>'bodega')) b, max(nullif(upper(trim(r->>'clave')),'')) c
      from jsonb_array_elements(p_rows) r group by 1) g
    where x.id = g.b and g.c is not null;
  delete from items where bodega_id in (select upper(trim(r->>'bodega')) from jsonb_array_elements(p_rows) r);
  insert into items(bodega_id, codigo, descripcion, sistema)
    select upper(trim(r->>'bodega')), r->>'codigo', r->>'descripcion', (r->>'sistema')::numeric
    from jsonb_array_elements(p_rows) r where coalesce(trim(r->>'bodega'),'') <> '';
  get diagnostics n = row_count; return n;
end $$;

-- Resumen para el dashboard
create or replace function admin_resumen() returns table(id text, nombre text, done boolean, done_at timestamptz, n bigint, contados bigint, dif numeric)
language sql as $$
  select b.id, b.nombre, b.done, b.done_at, count(i.id), count(i.fisico),
         coalesce(sum(case when i.fisico is not null then i.fisico - i.sistema end),0)
  from bodegas b left join items i on i.bodega_id = b.id group by b.id order by b.id $$;

-- Lista maestra de bodegas (existen aunque no tengan saldo en sistema). Contraseña inicial = nombre de la bodega.
insert into bodegas(id, clave_hash)
  select b, extensions.crypt(b, extensions.gen_salt('bf')) from unnest(array[
  'B300','B301','B302','B303','B304','B306','B307','B308','B309','B311','B312','B314','B315','B316','B318','B319','B320',
  'B321','B322','B323','B324','B325','B328','B329','B330','B331','B332','B333','B334','B335','B336','B337','B338','B339',
  'B501','B502','B503','B504','B505','B801','B802','B803']) b
  on conflict (id) do nothing;

-- Permisos de ejecución
revoke all on function bodega_login(text,text), bodega_guardar(text,text,jsonb,jsonb), bodega_catalogo(text,text), admin_cargar(jsonb), admin_resumen() from public, anon, authenticated;
grant execute on function bodega_login(text,text), bodega_guardar(text,text,jsonb,jsonb), bodega_catalogo(text,text) to anon, authenticated;
grant execute on function admin_cargar(jsonb), admin_resumen() to authenticated;
