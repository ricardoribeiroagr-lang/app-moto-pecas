-- =====================================================================
-- Migração 05: distância de deslocamento por veículo da frota
-- Ao escolher o veículo no orçamento, essa distância entra sozinha
-- no campo "Deslocamento" (dá para mudar em cada OS).
-- =====================================================================
alter table motos add column if not exists desloc_km numeric(8,1) check (desloc_km >= 0);

-- frota da Embrasil: os valores informados eram deslocamento, não km do painel
update motos set desloc_km = v.d, km = null
from (values ('UBF5A62',42),('UBF5A59',12),('UBF1H27',48),('TDX4B79',42),('UBF5A65',113),('UBF5A61',126)) as v(placa, d)
where motos.placa = v.placa;
