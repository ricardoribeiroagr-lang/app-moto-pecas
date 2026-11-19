-- =====================================================================
-- Migração 03: só o administrador exclui OS
-- A equipe continua vendo, criando e mudando o status das OS.
-- Ao excluir uma OS, os itens dela saem juntos (on delete cascade).
-- =====================================================================
drop policy if exists equipe    on ordens_servico;
drop policy if exists os_ler    on ordens_servico;
drop policy if exists os_insere on ordens_servico;
drop policy if exists os_altera on ordens_servico;
drop policy if exists os_apaga  on ordens_servico;
create policy os_ler    on ordens_servico for select to authenticated using (true);
create policy os_insere on ordens_servico for insert to authenticated with check (true);
create policy os_altera on ordens_servico for update to authenticated using (true) with check (true);
create policy os_apaga  on ordens_servico for delete to authenticated using (is_admin());

drop policy if exists equipe       on itens_os;
drop policy if exists itens_ler    on itens_os;
drop policy if exists itens_insere on itens_os;
drop policy if exists itens_altera on itens_os;
drop policy if exists itens_apaga  on itens_os;
create policy itens_ler    on itens_os for select to authenticated using (true);
create policy itens_insere on itens_os for insert to authenticated with check (true);
create policy itens_altera on itens_os for update to authenticated using (true) with check (true);
create policy itens_apaga  on itens_os for delete to authenticated using (is_admin());
