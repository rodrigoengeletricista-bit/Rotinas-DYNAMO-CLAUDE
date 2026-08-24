# Rotinas Dynamo + Claude

Rotinas de automação e auditoria para Revit, com scripts Python/PowerShell
gerados e assistidos por Claude.

## Rotinas Dynamo

- `Dynamo_ebpos_Cloude.dyn` — Inserção de barramentos elétricos (busway) por nível no Revit
- `MEGA Rotina_EDF_EBPOS.dyn` — Rotina MEGA para EDF/EBPOS

## Auditoria de vínculos

- `scripts/Auditoria-Vinculos.ps1` — Varre a pasta do projeto e diagnostica
  vínculos IFC/RVT/PDF: inflação da conversão IFC→RVT, duplicatas por hash,
  conversões defasadas, nomenclatura, revisão de PDF × modelo, higiene de
  caminho e peso morto. Somente leitura.

```powershell
.\scripts\Auditoria-Vinculos.ps1 -Raiz "C:\BIM\2001-HB3321" -Deep -CsvOut "C:\Temp\auditoria.csv"
```

## Documentação

- `docs/ANALISE_VINCULOS_HB3321.md` — Análise dos vínculos ARQ/ELE/BARRAMENTO
  da obra Gonçalves Dias: por que o RVT vindo de IFC engorda, qual formato IFC
  pedir, posicionamento por coordenadas compartilhadas e plano de ação
- `docs/PADRAO_PASTAS_CDE.md` — Estrutura de pastas CDE (ABNT NBR ISO 19650),
  nomenclatura de arquivos e fluxo de conversão IFC→RVT

## Requisitos

- Autodesk Revit (com Dynamo integrado)
- CPython3 engine habilitada no Dynamo
- Windows PowerShell 5.1 ou superior (para os scripts de auditoria)
