# Rotinas Dynamo + Claude

Rotinas de automação para Revit usando Dynamo, com scripts Python gerados/assistidos por Claude.
Foco: modelagem de prumada de barramento blindado (busway) a partir de traçado de eletrocalha.

## Arquivos

- `MEGA Rotina_EDF_EBPOS.dyn` — rotina de produção: substitui eletrocalhas selecionadas por
  peças de barramento (reto / derivação / redução), escolhidas pelo nome do nível.
- `Dynamo_ebpos_Cloude.dyn` — protótipo. O nó Python está desconectado e não insere nada;
  seu valor é o dicionário `MAPA_NIVEIS`, que descreve a prumada nível a nível.

## Documentação

- [`docs/ANALISE_ROTINAS_E_MODELO.md`](docs/ANALISE_ROTINAS_E_MODELO.md) — auditoria das
  rotinas e do modelo: defeitos por severidade, divergências entre as duas rotinas e plano
  de correção.
- [`docs/TEMPLATE_BARRAMENTO_BLINDADO.md`](docs/TEMPLATE_BARRAMENTO_BLINDADO.md) — roteiro de
  estruturação do template Revit: navegador de projetos, parâmetros, filtros, templates de
  vista e nomenclatura de vistas, cortes e elevações.

## Requisitos

- Autodesk Revit 2025 (validado em 2025.4) com Dynamo 3.x
- CPython3 engine habilitada no Dynamo
- Famílias de barramento carregadas: `Barramento-Reto`, `Barramento-Derivação-1 Plugue`,
  `Barramento-Redução-400A-2500A`
