-- =====================================================================
-- Migração 04: empresas clientes com frota e tabela de preços própria
-- (ex.: Embrasil Segurança). A oficina faz as OS da empresa: escolhe a
-- empresa, o veículo da frota e os serviços da tabela dela.
-- A empresa não tem login: recebe as OS por PDF/WhatsApp.
-- =====================================================================

create table if not exists empresas (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null,
  cliente_id uuid not null references clientes(id),
  valor_hora numeric(10,2) not null default 90 check (valor_hora >= 0),
  telefone   text,
  created_at timestamptz not null default now()
);

-- a tabela "motos" passa a guardar qualquer veículo (moto ou carro) e a frota da empresa
alter table motos add column if not exists empresa_id uuid references empresas(id) on delete set null;
alter table motos add column if not exists tipo text not null default 'moto';
alter table motos add column if not exists descricao text;
alter table motos add column if not exists ativo boolean not null default true;
alter table motos alter column modelo_id drop not null;
alter table motos drop constraint if exists motos_tipo_check;
alter table motos add constraint motos_tipo_check check (tipo in ('moto','carro'));

-- tabela de preços própria de cada empresa (serviços de moto e de carro)
create table if not exists tabela_empresa (
  id         bigint generated always as identity primary key,
  empresa_id uuid not null references empresas(id) on delete cascade,
  tipo       text not null check (tipo in ('moto','carro')),
  peca_id    text not null,
  peca_nome  text not null,
  servico    text not null,
  preco      numeric(10,2) not null default 0 check (preco >= 0),  -- preço da peça
  horas      numeric(5,2)  not null default 0 check (horas >= 0),  -- mão de obra (× valor da hora da empresa)
  ativo      boolean not null default true,
  ordem      int not null default 0
);
create index if not exists tabela_empresa_idx on tabela_empresa (empresa_id, tipo);

alter table ordens_servico add column if not exists empresa_id uuid references empresas(id) on delete set null;
alter table ordens_servico add column if not exists obs text;
alter table itens_os add column if not exists tabela_id bigint references tabela_empresa(id) on delete set null;

-- ---------- Criar OS de empresa --------------------------------------
-- Preços vêm da tabela da empresa e são calculados aqui.
create or replace function criar_os_empresa(
  p_empresa uuid, p_veiculo uuid, p_km int, p_obs text, p_itens jsonb,   -- [{"tabela_id":1,"qtd":1}]
  p_desloc_km numeric default 0, p_desloc_valor_km numeric default 0
) returns bigint language plpgsql security invoker as $$
declare v_cli uuid; v_hora numeric; v_tipo text; v_os bigint; v_pc numeric; v_mo numeric;
begin
  select cliente_id, valor_hora into v_cli, v_hora from empresas where id = p_empresa;
  if v_cli is null then raise exception 'Empresa inválida'; end if;
  select tipo into v_tipo from motos where id = p_veiculo and empresa_id = p_empresa;
  if v_tipo is null then raise exception 'Veículo não pertence a esta empresa'; end if;
  p_itens := coalesce(p_itens, '[]'::jsonb);
  p_desloc_km := greatest(coalesce(p_desloc_km, 0), 0);
  p_desloc_valor_km := greatest(coalesce(p_desloc_valor_km, 0), 0);
  if jsonb_array_length(p_itens) = 0 and p_desloc_km * p_desloc_valor_km = 0 then
    raise exception 'Orçamento sem itens';
  end if;

  insert into ordens_servico (cliente_id, moto_id, km, valor_hora, empresa_id, obs, desloc_km, desloc_valor_km)
    values (v_cli, p_veiculo, p_km, v_hora, p_empresa, nullif(trim(p_obs), ''), p_desloc_km, p_desloc_valor_km)
    returning id into v_os;

  insert into itens_os (os_id, tabela_id, peca_nome, servico, qtd, preco_unit, horas, valor_hora)
  select v_os, t.id, t.peca_nome, t.servico, greatest((i->>'qtd')::int, 1), t.preco, t.horas, v_hora
  from jsonb_array_elements(p_itens) i
  join tabela_empresa t on t.id = (i->>'tabela_id')::bigint
                       and t.empresa_id = p_empresa and t.ativo and t.tipo = v_tipo;

  select coalesce(sum(qtd * preco_unit), 0), coalesce(sum(qtd * horas * valor_hora), 0)
    into v_pc, v_mo from itens_os where os_id = v_os;
  update ordens_servico set total_pecas = v_pc, total_mo = round(v_mo, 2) where id = v_os;
  if p_km is not null then update motos set km = p_km where id = p_veiculo; end if;
  return v_os;
end $$;
revoke execute on function criar_os_empresa(uuid, uuid, int, text, jsonb, numeric, numeric) from anon, public;
grant  execute on function criar_os_empresa(uuid, uuid, int, text, jsonb, numeric, numeric) to authenticated;

-- ---------- Permissões: equipe lê; só o administrador cadastra -------
grant select, insert, update, delete on empresas, tabela_empresa to authenticated;
grant usage, select on all sequences in schema public to authenticated;
alter table empresas       enable row level security;
alter table tabela_empresa enable row level security;

drop policy if exists ler on empresas;
drop policy if exists admin_insere on empresas;
drop policy if exists admin_altera on empresas;
drop policy if exists admin_apaga on empresas;
create policy ler          on empresas for select to authenticated using (true);
create policy admin_insere on empresas for insert to authenticated with check (is_admin());
create policy admin_altera on empresas for update to authenticated using (is_admin()) with check (is_admin());
create policy admin_apaga  on empresas for delete to authenticated using (is_admin());

drop policy if exists ler on tabela_empresa;
drop policy if exists admin_insere on tabela_empresa;
drop policy if exists admin_altera on tabela_empresa;
drop policy if exists admin_apaga on tabela_empresa;
create policy ler          on tabela_empresa for select to authenticated using (true);
create policy admin_insere on tabela_empresa for insert to authenticated with check (is_admin());
create policy admin_altera on tabela_empresa for update to authenticated using (is_admin()) with check (is_admin());
create policy admin_apaga  on tabela_empresa for delete to authenticated using (is_admin());

-- ---------- Primeira empresa: Embrasil Segurança ----------------------
do $$
declare v_cli uuid;
begin
  if not exists (select 1 from empresas where nome = 'Embrasil Segurança') then
    insert into clientes (nome) values ('Embrasil Segurança') returning id into v_cli;
    insert into empresas (nome, cliente_id) values ('Embrasil Segurança', v_cli);
  end if;
end $$;
