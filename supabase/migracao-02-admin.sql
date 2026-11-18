-- =====================================================================
-- Migração 02: administração do catálogo pelo app
-- Só o administrador cadastra e altera peças, serviços, modelos e valores
-- padrão. Os demais usuários logados só leem.
-- =====================================================================

-- ---------- Quem é administrador --------------------------------------
create table if not exists admins (
  email text primary key
);
insert into admins (email) values ('ricardoribeiro94@hotmail.com') on conflict do nothing;
alter table admins enable row level security;   -- sem políticas: ninguém lê direto, só pela função abaixo

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke execute on function is_admin() from anon, public;
grant  execute on function is_admin() to authenticated;

-- ---------- Valores padrão (hora de mão de obra e km) ----------------
create table if not exists config (
  id         int primary key default 1 check (id = 1),
  valor_hora numeric(10,2) not null default 90  check (valor_hora >= 0),
  valor_km   numeric(10,2) not null default 2.5 check (valor_km >= 0),
  updated_at timestamptz not null default now()
);
insert into config (id) values (1) on conflict do nothing;
alter table config enable row level security;
grant select, update on config to authenticated;
drop policy if exists config_ler   on config;
drop policy if exists config_admin on config;
create policy config_ler   on config for select to authenticated using (true);
create policy config_admin on config for update to authenticated using (is_admin()) with check (is_admin());

-- ---------- Catálogo e modelos: todos leem, só o admin altera --------
drop policy if exists equipe       on catalogo;
drop policy if exists ler          on catalogo;
drop policy if exists admin_insere on catalogo;
drop policy if exists admin_altera on catalogo;
drop policy if exists admin_apaga  on catalogo;
create policy ler          on catalogo for select to authenticated using (true);
create policy admin_insere on catalogo for insert to authenticated with check (is_admin());
create policy admin_altera on catalogo for update to authenticated using (is_admin()) with check (is_admin());
create policy admin_apaga  on catalogo for delete to authenticated using (is_admin());

drop policy if exists equipe       on modelos;
drop policy if exists ler          on modelos;
drop policy if exists admin_insere on modelos;
drop policy if exists admin_altera on modelos;
drop policy if exists admin_apaga  on modelos;
create policy ler          on modelos for select to authenticated using (true);
create policy admin_insere on modelos for insert to authenticated with check (is_admin());
create policy admin_altera on modelos for update to authenticated using (is_admin()) with check (is_admin());
create policy admin_apaga  on modelos for delete to authenticated using (is_admin());
