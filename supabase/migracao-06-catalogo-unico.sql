-- =====================================================================
-- Migração 06: catálogo único para particulares e empresas
-- O catálogo passa a ter serviços de moto e de carro. As empresas usam o
-- mesmo catálogo (com o ajuste de preço do modelo do veículo).
-- Os serviços que só existiam na tabela de empresa entram no catálogo.
-- A tabela_empresa fica guardada, mas o app não usa mais.
-- =====================================================================
alter table catalogo add column if not exists tipo text not null default 'moto';
alter table catalogo drop constraint if exists catalogo_tipo_check;
alter table catalogo add constraint catalogo_tipo_check check (tipo in ('moto','carro'));

insert into catalogo (tipo, peca_id, peca_nome, servico, preco, horas, ativo, ordem)
select distinct on (t.tipo, t.peca_id, lower(t.servico))
       t.tipo, t.peca_id, t.peca_nome, t.servico, t.preco, t.horas, t.ativo, t.ordem
from tabela_empresa t
where not exists (select 1 from catalogo c
                  where c.tipo = t.tipo and c.peca_id = t.peca_id and lower(c.servico) = lower(t.servico))
order by t.tipo, t.peca_id, lower(t.servico), t.id;

-- OS de empresa passa a usar o catálogo
drop function if exists criar_os_empresa(uuid, uuid, int, text, jsonb, numeric, numeric);
create or replace function criar_os_empresa(
  p_empresa uuid, p_veiculo uuid, p_km int, p_obs text, p_itens jsonb,   -- [{"catalogo_id":1,"qtd":1}]
  p_desloc_km numeric default 0, p_desloc_valor_km numeric default 0, p_valor_hora numeric default null
) returns bigint language plpgsql security invoker as $$
declare v_cli uuid; v_hora numeric; v_tipo text; v_mult numeric; v_os bigint; v_pc numeric; v_mo numeric;
begin
  select cliente_id, coalesce(p_valor_hora, valor_hora) into v_cli, v_hora from empresas where id = p_empresa;
  if v_cli is null then raise exception 'Empresa inválida'; end if;
  select m.tipo, coalesce(mo.multiplicador, 1) into v_tipo, v_mult
    from motos m left join modelos mo on mo.id = m.modelo_id
   where m.id = p_veiculo and m.empresa_id = p_empresa;
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

  insert into itens_os (os_id, catalogo_id, peca_nome, servico, qtd, preco_unit, horas, valor_hora)
  select v_os, c.id, c.peca_nome, c.servico, greatest((i->>'qtd')::int, 1), round(c.preco * v_mult, 2), c.horas, v_hora
  from jsonb_array_elements(p_itens) i
  join catalogo c on c.id = (i->>'catalogo_id')::bigint and c.ativo and c.tipo = v_tipo;

  select coalesce(sum(qtd * preco_unit), 0), coalesce(sum(qtd * horas * valor_hora), 0)
    into v_pc, v_mo from itens_os where os_id = v_os;
  update ordens_servico set total_pecas = v_pc, total_mo = round(v_mo, 2) where id = v_os;
  if p_km is not null then update motos set km = p_km where id = p_veiculo; end if;
  return v_os;
end $$;
revoke execute on function criar_os_empresa(uuid, uuid, int, text, jsonb, numeric, numeric, numeric) from anon, public;
grant  execute on function criar_os_empresa(uuid, uuid, int, text, jsonb, numeric, numeric, numeric) to authenticated;
