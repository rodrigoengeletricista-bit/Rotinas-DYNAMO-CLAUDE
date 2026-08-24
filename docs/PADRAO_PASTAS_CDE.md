# Padrão de pastas CDE — escritório de projetos BIM

Estrutura baseada nos quatro estados do Ambiente Comum de Dados da
**ABNT NBR ISO 19650-1/2**: Trabalho em Andamento → Compartilhado → Publicado → Arquivo.

Um arquivo nunca "está em duas pastas". Ele **transita entre estados**, e cada
transição tem um responsável e um critério de aprovação. É isso que a estrutura
materializa em disco.

---

## 1. Estrutura raiz

```
C:\BIM\
└── 2001-HB3321-GONCALVES-DIAS\
    ├── 00-GESTAO\
    ├── 10-WIP\
    ├── 20-COMPARTILHADO\
    ├── 30-PUBLICADO\
    ├── 40-ARQUIVO\
    └── 50-RECEBIDOS\
```

Prefixo numérico força a ordenação e deixa a leitura do fluxo evidente na tela.

---

## 2. Detalhamento

### `00-GESTAO` — regras do jogo

```
00-GESTAO\
├── 01-BEP\                  Plano de Execução BIM, matriz de responsabilidades, LOD
├── 02-TEMPLATES\            .rte, .rft, tabelas, filtros de vista
├── 03-BIBLIOTECAS\
│   ├── FAMILIAS\
│   └── PARAMETROS\          shared parameters oficiais do escritório
├── 04-PADROES\              nomenclatura, camadas, config. de export IFC/DWG/PDF
└── 05-ROTINAS\              Dynamo, PyRevit, scripts de auditoria
```

### `10-WIP` — trabalho em andamento (só a equipe interna)

```
10-WIP\
├── ARQ\  ELE\  EST\  HID\  CLI\  SPK\  ...
│   ├── MODELOS\             .rvt de autoria — só o autor edita
│   ├── FAMILIAS\            famílias em desenvolvimento
│   ├── ESTUDOS\             tentativas, opções, descartáveis
│   └── BACKUP\              destino dos .0001.rvt (fora do modelo!)
```

Regras:
- ninguém de fora da disciplina abre nada aqui;
- nenhum vínculo aponta para `10-WIP` — vínculo só aponta para `20-COMPARTILHADO`;
- backups do Revit vão para `BACKUP\`, nunca convivem com o modelo ativo.

### `20-COMPARTILHADO` — troca entre disciplinas ⭐

É daqui que **todo vínculo é carregado**. Nenhuma exceção.

```
20-COMPARTILHADO\
├── MODELOS-RVT\             ← vínculos .rvt (nativos e convertidos de IFC)
├── MODELOS-IFC\             ← IFC recebido/emitido, formato de troca
├── CONVERSAO-IFC\           ← área técnica da conversão (ver seção 3)
├── FEDERADO-NWC\            ← .nwc/.nwd para Navisworks
├── CAD-DWG\
└── REFERENCIAS-PDF\         ← plantas de referência, com revisão no nome
```

### `30-PUBLICADO` — emissão formal, congelada

```
30-PUBLICADO\
├── R00_2026-05-18\
├── R01_2026-06-02\
│   ├── PDF\  IFC\  DWG\  RVT\
│   └── PROTOCOLO.pdf        quem emitiu, quando, para quem, o que
```

Pasta de revisão publicada é **somente leitura**. Não se corrige o publicado:
abre-se a revisão seguinte.

### `40-ARQUIVO` — versões superadas

```
40-ARQUIVO\
└── 2026-05-18_ARQ-R04\
```

Sai de circulação mas não some — é o que sustenta rastreabilidade em perícia,
medição e discussão de aditivo.

### `50-RECEBIDOS` — terceiros

```
50-RECEBIDOS\
├── FORNECEDORES\
│   └── BARRAMENTO\
│       ├── ORIGINAL\        exatamente como chegou, jamais alterado
│       └── TRATADO\         renomeado, posicionado, no padrão do escritório
├── CLIENTE\
└── CONSULTORES\
```

`ORIGINAL\` é evidência: prova o que o fornecedor entregou e em que data. Só se
trabalha sobre `TRATADO\`.

---

## 3. Fluxo de conversão IFC → RVT

Pasta dedicada, porque o Revit gera três subprodutos ao lado de cada IFC importado
e eles não podem poluir a área de vínculos:

```
20-COMPARTILHADO\CONVERSAO-IFC\
├── ENTRADA\                 IFC recebido, sem tratamento
├── TRABALHO\                onde o Revit despeja:
│                              X.ifc.rvt
│                              X.ifc.log
│                              X.ifc.shared-parameters.txt
└── (saída → 20-COMPARTILHADO\MODELOS-RVT\ já renomeado e purgado)
```

Procedimento, a cada revisão recebida:

1. IFC entra em `ENTRADA\`, já com o nome no padrão do escritório
2. copiar para `TRABALHO\` e abrir no Revit (Abrir → IFC)
3. **Gerenciar → Purgar Não Utilizados** (repetir até esgotar) e **Auditar**
4. conferir a origem e as coordenadas
5. `Salvar Como` em `MODELOS-RVT\` com o nome limpo — **sem** o `.ifc`
6. `TRABALHO\` é lixo descartável: pode ser esvaziada a qualquer momento

Por que não vincular o IFC direto: ao vincular um IFC, o Revit gera o `.ifc.rvt`
ao lado e vincula esse arquivo. Ele é regenerado a cada importação e **sobrescreve
qualquer alteração sem avisar**. Converter uma vez, de forma controlada, e vincular
o RVT limpo elimina o risco e o custo de reimportação a cada abertura.

---

## 4. Nomenclatura

```
PROJ - FASE - DISC - SEQ - TIPO - Rxx . ext

2001 - EXE  - ARQ  - 0001 - MOD  - R05 . rvt
```

| Campo | Conteúdo | Exemplos |
|---|---|---|
| PROJ | número do projeto | `2001` |
| FASE | etapa | `EVD` `ANT` `LEG` `BAS` `EXE` `ASB` |
| DISC | disciplina (**não** a origem) | `ARQ` `EST` `ELE` `HID` `CLI` `SPK` `TEL` `URB` |
| SEQ | sequencial dentro da disciplina | `0001` `0020` |
| TIPO | natureza do arquivo | `MOD` `COORD` `BARR` `DET` `FED` |
| Rxx | revisão | `R00` … `R99` |

Proibido no nome: acento, cedilha, apóstrofo, espaço duplo, parêntese, carimbo
automático de data/hora. Fornecedor é registrado pela **pasta** (`50-RECEBIDOS\`)
e pelo BEP — nunca ocupando o campo de disciplina.

Aplicado ao caso HB 3321:

| Hoje | Padrão |
|---|---|
| `2001-EXE-ARQ-0001-MOD-R05.ifc.rvt` | `2001-EXE-ARQ-0001-MOD-R05.rvt` |
| `2001-EXE-ELE-0001-MOD-R04.ifc.rvt` | `2001-EXE-ELE-0001-MOD-R04.rvt` |
| `2001-EXE-FOR-0020-GER-R07(26-09-24_10h17min29s).ifc.rvt` | `2001-EXE-ELE-0020-BARR-R07.rvt` |
| `ELET_GUIA.rvt` | `2001-EXE-ELE-0000-COORD-R00.rvt` |

---

## 5. Higiene de caminho

| Regra | Motivo |
|---|---|
| Raiz curta: `C:\BIM\` | o Windows ainda quebra em 260 caracteres |
| Sem acento, cedilha ou apóstrofo | quebra Dynamo, Python, linha de comando e upload ACC |
| Sem espaço nos níveis técnicos | evita aspas em todo script |
| Modelo ativo **fora** de OneDrive/Dropbox/GDrive | conflito de bloqueio corrompe `.rvt` |
| Sincronizado só para troca e publicação | backup sim, área de trabalho não |

Caminho atual do HB 3321 (`...\OneDrive\Desktop\Rotinas_DYNAMO_CLAUDE\VERIFICAÇÃO DE MODELOS\HB 3321 - OBRA Gonçaves Dias\VÍNCULOS\IFC's\`)
viola cinco das cinco regras.

---

## 6. Onde cada estado vive

| Estado | Local | Acesso |
|---|---|---|
| `10-WIP` | disco local ou ACC/Revit Server | autor da disciplina |
| `20-COMPARTILHADO` | ACC / servidor / SharePoint | leitura para todos, escrita pelo coordenador |
| `30-PUBLICADO` | CDE oficial do contrato | leitura para todos, escrita só na emissão |
| `40-ARQUIVO` | armazenamento frio + backup | leitura |
| `50-RECEBIDOS` | CDE | escrita pelo coordenador |

Se o escritório usa ACC/BIM 360, `20`, `30`, `40` e `50` viram pastas do
Docs com permissão por pasta, e `10-WIP` vira o Project Files com worksharing
em nuvem.
