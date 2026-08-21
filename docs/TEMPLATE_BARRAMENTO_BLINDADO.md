# Roteiro de Estruturação de Template — Modelagem de Barramentos Blindados (Busway)

Guia de organização do **Navegador de Projetos**, **Propriedades de vista**, **Filtros**,
**Templates de Vista** e **nomenclatura** de vistas, cortes e elevações, orientado ao fluxo
de prumadas de barramento blindado usado nas rotinas Dynamo deste repositório.

> Contexto do modelo atual (extraído de `Dynamo_ebpos_Cloude.dyn`):
> prumada vertical de busway saindo do QGBT no subsolo e subindo até o ático, com peças
> `Barramento-Reto`, `Barramento-Derivação-1 Plugue` e `Barramento-Redução-1250A-1000A`,
> e níveis nomeados no padrão `(-1)NO-SUBSOLO-ELT`, `00NA-TÉRREO-ELT`,
> `01NA-2º PAVIMENTO - TIPO-ELT` … `06NA-ÁTICO-ELT`.
> Todo o roteiro abaixo assume e preserva esse padrão de níveis.

---

## 0. Ordem de execução (faça nesta sequência)

A ordem importa: parâmetros vêm antes de tudo, porque browser, filtros e templates dependem deles.

1. Padronizar **níveis** e **subprojetos/worksets**
2. Criar os **parâmetros de projeto** de vista (§1)
3. Criar os **Filtros de Vista** (§2)
4. Criar os **Templates de Vista** já com os filtros aplicados (§3)
5. Criar a **Organização do Navegador de Projetos** (§4)
6. Criar as **vistas-modelo** (uma de cada tipo) já nomeadas (§5, §6)
7. Criar folhas, legendas e tabelas (§7)
8. Rodar o **checklist de fechamento** (§9) e salvar como `.rte`

---

## 1. Parâmetros de projeto (a base de tudo)

Sem parâmetros próprios, o Navegador de Projetos só consegue agrupar por Disciplina /
Tipo de Vista / Nível — insuficiente para um modelo elétrico com prumada.

`Gerenciar > Parâmetros de Projeto > Adicionar`. Crie como **parâmetro compartilhado**
(vai para tabelas e folhas) e marque as categorias indicadas.

### 1.1 Parâmetros aplicados a **Vistas**

| Parâmetro | Tipo | Valores sugeridos | Para que serve |
|---|---|---|---|
| `ZZ_Fase_Projeto` | Texto | `01-EP`, `02-AP`, `03-PE`, `99-WIP` | 1º nível do navegador |
| `ZZ_Disciplina` | Texto | `ELT`, `HID`, `ARQ`, `EST`, `COORD` | 2º nível |
| `ZZ_Subdisciplina` | Texto | `ELT-BUSWAY`, `ELT-FORCA`, `ELT-ILUM`, `ELT-SPDA`, `ELT-QGBT` | 3º nível — **é aqui que o busway se isola** |
| `ZZ_Tipo_Documento` | Texto | `PLANTA`, `CORTE`, `ELEVACAO`, `DETALHE`, `3D`, `TRABALHO`, `COORDENACAO` | 4º nível |
| `ZZ_Prumada` | Texto | `PR-01`, `PR-02`, … | separa vistas por prumada |
| `ZZ_Uso` | Texto | `EMISSAO`, `TRABALHO`, `DESCARTAVEL` | permite esconder lixo de WIP |

> O campo nativo **Sub-Disciplina** (visível na sua janela de Propriedades) só existe em
> algumas versões/gabaritos e não é confiável para filtragem entre disciplinas.
> Use `ZZ_Subdisciplina` próprio e deixe o nativo em branco.

O prefixo `ZZ_` mantém os parâmetros agrupados no fim da lista de Propriedades, longe dos
nativos que você usa no dia a dia.

### 1.2 Parâmetros aplicados a **Conexões de Cabos / Bandejas / Equipamento Elétrico**
(as categorias em que o busway é modelado — tipicamente *Cable Tray*/*Conduíte* ou família
genérica; ajuste conforme a família usada nas rotinas)

| Parâmetro | Tipo | Exemplo | Uso |
|---|---|---|---|
| `ELT_Sistema` | Texto | `BUSWAY-PRUMADA`, `BUSWAY-DERIVACAO` | filtro gráfico e tabela |
| `ELT_Prumada` | Texto | `PR-01` | rastreia trecho ↔ vista |
| `ELT_Corrente_A` | Inteiro | `1250`, `1000` | filtro por corrente (cor por amperagem) |
| `ELT_Nivel_Origem` | Texto | `00NA-TÉRREO-ELT` | alimentado pela rotina Dynamo |
| `ELT_Alimenta_CM` | Texto | `CM_TERREO`, `CM_DUPLEX` | espelha o campo `cm` do `MAPA_NIVEIS` |
| `ELT_Tipo_Peca` | Texto | `RETO`, `DERIVACAO`, `REDUCAO`, `CURVA`, `FLANGE` | filtro por tipo de peça |

> **Ganho direto:** esses seis parâmetros são exatamente as chaves que a rotina Dynamo já
> manipula. Se a rotina passar a escrevê-los na inserção, filtros, tabelas de quantitativo
> e verificação de prumada passam a ser automáticos.

---

## 2. Filtros de Vista

`Vista > Filtros > Novo`. Prefira **filtros por regra** (paramétricos) a filtros de seleção —
filtro de seleção quebra quando a rotina recria os elementos.

### 2.1 Filtros de destaque do busway

| Nome do filtro | Categorias | Regra | Substituição gráfica |
|---|---|---|---|
| `ELT-BUSWAY-Prumada` | Cable Tray / Modelo Genérico / Eq. Elétrico | `ELT_Sistema` = `BUSWAY-PRUMADA` | Linhas vermelhas, peso 5, preenchimento sólido |
| `ELT-BUSWAY-Derivacao` | idem | `ELT_Sistema` = `BUSWAY-DERIVACAO` | Laranja, peso 4 |
| `ELT-BUSWAY-1250A` | idem | `ELT_Corrente_A` = `1250` | Vermelho escuro |
| `ELT-BUSWAY-1000A` | idem | `ELT_Corrente_A` = `1000` | Vermelho claro |
| `ELT-BUSWAY-Reducao` | idem | `ELT_Tipo_Peca` = `REDUCAO` | Amarelo + hachura, alta visibilidade |
| `ELT-BUSWAY-SemParametro` | idem | `ELT_Sistema` **não tem valor** | **Magenta puro** — é o filtro de QA |

> `ELT-BUSWAY-SemParametro` é o mais importante do conjunto: qualquer peça inserida pela
> rotina que não recebeu parâmetro acende em magenta na vista. Vira verificação visual
> instantânea depois de cada execução do Dynamo.

### 2.2 Filtros de contexto (aplicados em todos os templates ELT)

| Nome | Regra | Ação |
|---|---|---|
| `CTX-Arquitetura-Fundo` | Categorias ARQ | Cinza 60%, meio-tom, sem preenchimento |
| `CTX-Estrutura-Fundo` | Categorias EST | Cinza 40%, linha tracejada |
| `CTX-Outras-Disciplinas-OFF` | HID/AVAC | Desmarcar Visibilidade |
| `QA-Nao-Aprovado` | `Comentários` contém `REVISAR` | Vermelho + hachura diagonal |

### 2.3 Convenção de nome de filtro

`<GRUPO>-<ASSUNTO>-<CRITÉRIO>` — ex.: `ELT-BUSWAY-1250A`, `CTX-Arquitetura-Fundo`.
Grupos: `ELT`, `CTX` (contexto), `QA` (verificação), `PUB` (publicação).
Assim a lista de filtros fica ordenada por função, não por ordem de criação.

---

## 3. Templates de Vista

`Vista > Templates de Vista > Gerenciar`. Crie **um template por tipo de documento**, nunca
um template por pavimento — o pavimento é resolvido pelo Plano de Corte, não por template.

### 3.1 Conjunto mínimo para o busway

| Template | Base | Escala | Detalhe | Disciplina | Observações-chave |
|---|---|---|---|---|---|
| `ELT-BUSWAY-Planta-Emissao` | Planta de piso | 1:50 | Alto | Elétrica | Filtros ELT + CTX; subjacência do pav. inferior em cinza |
| `ELT-BUSWAY-Planta-Trabalho` | Planta de piso | 1:50 | Alto | Coordenação | Tudo visível, filtros de QA ligados, sem anotação |
| `ELT-BUSWAY-Corte-Prumada` | Corte | 1:50 | Alto | Elétrica | **O documento principal do busway** — ver §3.2 |
| `ELT-BUSWAY-Elevacao-Shaft` | Elevação | 1:25 | Alto | Elétrica | Vista frontal do shaft, com cotas de nível |
| `ELT-BUSWAY-Detalhe` | Detalhe/Callout | 1:10 / 1:20 | Alto | Elétrica | Derivação, redução, fixação, travessia de laje |
| `ELT-BUSWAY-3D-Isometrico` | 3D | — | Alto | Elétrica | Só busway + lajes, para conferência |
| `ELT-COORD-Interferencia` | 3D / Planta | 1:50 | Alto | Coordenação | Todas as disciplinas, meio-tom, busway em vermelho |

### 3.2 O template `ELT-BUSWAY-Corte-Prumada` (detalhe)

É o corte longitudinal que mostra a prumada inteira do subsolo ao ático — o desenho que
comunica o projeto. Configure:

- **Faixa de vista / Profundidade de corte:** apenas a largura do shaft (evita puxar o
  edifício inteiro para dentro do corte)
- **Caixa de escopo:** crie uma `SC-PRUMADA-PR-01` envolvendo o shaft e aplique-a à vista —
  isso trava a extensão e impede que o corte "cresça" ao modelar
- **Níveis:** visíveis, com a nomenclatura completa `00NA-TÉRREO-ELT` aparecendo
- **Arquitetura/Estrutura:** apenas lajes, em meio-tom (filtro `CTX-*-Fundo`)
- **Anotações:** tags de família e de corrente ligadas; tags de circuito desligadas

### 3.3 Regras de uso

- **Atribua o template pelo campo *Template de vista*** nas Propriedades (trava a vista) —
  não use "Aplicar propriedades do template" (aplicação solta, que dessincroniza).
- Deixe **desprotegidos no template** apenas: Escala? não. Mantenha travado inclusive escala.
  Libere apenas `Caixa de escopo` e `Faixa da vista`, que variam por prumada/pavimento.
- Nomeie templates com o mesmo prefixo dos parâmetros (`ELT-BUSWAY-…`) para que a lista
  alfabética já agrupe por disciplina.

---

## 4. Organização do Navegador de Projetos

`Vista > Interface do Usuário > Navegador de Projetos` → clique com o botão direito em
*Vistas (…)* → **Navegador — Organização** → `Novo`.

### 4.1 Esquema `01-ELT-PRODUCAO` (o do dia a dia)

**Filtragem:** `ZZ_Disciplina` igual a `ELT`
**Agrupamento:**

```
1º  ZZ_Subdisciplina      →  ELT-BUSWAY / ELT-FORCA / ELT-ILUM / ELT-SPDA
2º  ZZ_Tipo_Documento     →  PLANTA / CORTE / ELEVACAO / DETALHE / 3D
3º  ZZ_Prumada            →  PR-01 / PR-02 / (vazio)
Classificação: Nome da vista, crescente
```

Resultado no navegador:

```
Vistas (01-ELT-PRODUCAO)
└── ELT-BUSWAY
    ├── PLANTA
    │   ├── PR-01
    │   │   ├── ELT-BUSWAY-PL-00NA-TERREO-PR01
    │   │   └── ELT-BUSWAY-PL-01NA-2PAV-TIPO-PR01
    ├── CORTE
    │   └── PR-01
    │       └── ELT-BUSWAY-CO-PRUMADA-PR01
    ├── ELEVACAO
    │   └── ELT-BUSWAY-EL-SHAFT-PR01-NORTE
    └── 3D
        └── ELT-BUSWAY-3D-GERAL
```

### 4.2 Esquemas complementares

| Esquema | Filtro | Agrupamento | Quando usar |
|---|---|---|---|
| `00-TODAS` | nenhum | Tipo de família / Nível | Diagnóstico, achar vista órfã |
| `02-COORDENACAO` | `ZZ_Tipo_Documento` = `COORDENACAO` | Disciplina / Nível | Reunião de compatibilização |
| `03-POR-FOLHA` | vistas em folhas | Número da folha | Conferência de prancha |
| `98-WIP` | `ZZ_Uso` = `TRABALHO` | Criador / Tipo | Limpeza periódica |
| `99-SEM-CLASSIFICACAO` | `ZZ_Disciplina` sem valor | Tipo de vista | **Caixa de entrada:** toda vista nova aparece aqui até ser classificada |

> O esquema `99` é o guarda-corpo do template. Enquanto ele tiver conteúdo, o modelo não
> está organizado — e o padrão fica autoexplicativo para quem entra no projeto depois.

### 4.3 Organização de **Folhas**

Filtragem: nenhuma. Agrupamento: `ZZ_Disciplina` → `ZZ_Subdisciplina`. Classificação:
Número da folha.

---

## 5. Nomenclatura de vistas

### 5.1 Regra geral

```
<DISCIPLINA>-<SUBDISCIPLINA>-<TIPO>-<LOCAL/ORIGEM>-<COMPLEMENTO>
```

- Somente **MAIÚSCULAS**, separador **hífen**, **sem acento** e **sem espaço**
  (nomes de vista entram em nomes de arquivo exportados — acento e espaço quebram
  export em lote e links).
- Códigos de tipo: `PL` planta · `PT` planta de teto · `CO` corte · `EL` elevação ·
  `DT` detalhe · `AM` ampliação/callout · `3D` tridimensional · `LG` legenda · `TB` tabela.

### 5.2 Exemplos aplicados aos níveis do modelo atual

| Nível no Revit | Nome da vista |
|---|---|
| `(-1)NO-SUBSOLO-ELT` | `ELT-BUSWAY-PL-M1NO-SUBSOLO-PR01` |
| `00NA-TÉRREO-ELT` | `ELT-BUSWAY-PL-00NA-TERREO-PR01` |
| `01NA-2º PAVIMENTO - TIPO-ELT` | `ELT-BUSWAY-PL-01NA-2PAV-TIPO-PR01` |
| `02NA-3º PAVIMENTO - TIPO-ELT` | `ELT-BUSWAY-PL-02NA-3PAV-TIPO-PR01` |
| `04NA-5º PAVIMENTO - DUPLEX INFERIOR-ELT` | `ELT-BUSWAY-PL-04NA-5PAV-DUPLEX-INF-PR01` |
| `05NA-6º PAVIMENTO - DUPLEX SUPERIOR-ELT` | `ELT-BUSWAY-PL-05NA-6PAV-DUPLEX-SUP-PR01` |
| `06NA-ÁTICO-ELT` | `ELT-BUSWAY-PL-06NA-ATICO-PR01` |

Note que o **prefixo numérico do nível (`00`, `01`, …) é mantido** no nome da vista: é ele
que garante a ordem correta (térreo → ático) na classificação alfabética do navegador.
Subsolo vira `M1` (menos 1) para não perder a ordenação com o parêntese/sinal.

### 5.3 Vistas de trabalho

Prefixe com `WIP-` e marque `ZZ_Uso = TRABALHO`:
`WIP-ELT-BUSWAY-CONFERE-DERIVACOES`. São descartáveis e nunca vão para folha.

---

## 6. Nomenclatura de cortes e elevações

### 6.1 Cortes

```
ELT-BUSWAY-CO-<ASSUNTO>-<IDENTIFICADOR>
```

| Situação | Nome | Tipo de corte |
|---|---|---|
| Prumada completa subsolo→ático | `ELT-BUSWAY-CO-PRUMADA-PR01` | Corte de edificação |
| Corte transversal no shaft | `ELT-BUSWAY-CO-SHAFT-PR01-T01` | Corte de edificação |
| Derivação no térreo (CM_TERREO) | `ELT-BUSWAY-CO-DERIVACAO-00NA-CM-TERREO` | Corte de detalhe |
| Redução 1250→1000 A no 5º pav. | `ELT-BUSWAY-CO-REDUCAO-04NA-1250-1000` | Corte de detalhe |
| Travessia de laje | `ELT-BUSWAY-CO-TRAVESSIA-LAJE-TIPO` | Corte de detalhe |

Use **tipos de corte distintos** (`Gerenciar > Estilos de objeto` / tipo de família de corte):
`Corte de Edificação`, `Corte de Detalhe`, `Corte de Referência (não exibir)`.
Cortes de trabalho no tipo *não exibir* param de poluir as plantas.

### 6.2 Elevações

```
ELT-BUSWAY-EL-<ELEMENTO>-<IDENTIFICADOR>-<ORIENTACAO>
```

Orientação sempre pelo **norte de projeto**: `NORTE`, `SUL`, `LESTE`, `OESTE`.

| Uso | Nome |
|---|---|
| Face frontal do shaft da prumada | `ELT-BUSWAY-EL-SHAFT-PR01-NORTE` |
| Face de acesso aos plugues | `ELT-BUSWAY-EL-SHAFT-PR01-LESTE` |
| Elevação do QGBT (origem da prumada) | `ELT-BUSWAY-EL-QGBT-M1NO-SUBSOLO-NORTE` |
| Painel de derivação no ático | `ELT-BUSWAY-EL-CM-CONDOMINIO-ATICO-SUL` |

### 6.3 Detalhes e ampliações

```
ELT-BUSWAY-DT-<COMPONENTE>-<VARIANTE>
```
Ex.: `ELT-BUSWAY-DT-SUPORTE-MOLA-LAJE`, `ELT-BUSWAY-DT-PLUGUE-DERIVACAO-400A`,
`ELT-BUSWAY-DT-JUNTA-EXPANSAO`, `ELT-BUSWAY-DT-FLANGE-PASSAGEM-LAJE`.

### 6.4 Marcas (o texto que aparece no desenho)

Nome da vista ≠ marca do corte. A marca segue o **número da folha**:
corte `07` na folha `ELT-05` → marca `07/ELT-05`. Configure em
`Propriedades do corte > Marca de detalhe` + `Número da folha`.

---

## 7. Folhas, legendas e tabelas

### 7.1 Numeração de folhas

```
ELT-BW-<NN>
```
| Faixa | Conteúdo |
|---|---|
| `ELT-BW-00` | Índice, convenções, legenda de simbologia do busway |
| `ELT-BW-01..09` | Plantas por pavimento |
| `ELT-BW-10..19` | Cortes de prumada e diagrama unifilar da prumada |
| `ELT-BW-20..29` | Elevações de shaft |
| `ELT-BW-30..39` | Detalhes construtivos |
| `ELT-BW-90..` | Tabelas / quantitativos |

Nome da folha em Título Capitalizado (vai impresso):
`ELT-BW-10 — Corte da Prumada PR-01`.

### 7.2 Tabelas que o template deve trazer prontas

| Tabela | Campos | Serve para |
|---|---|---|
| `TB-BUSWAY-Quantitativo` | `ELT_Tipo_Peca`, `ELT_Corrente_A`, Comprimento, Contagem, agrupado por `ELT_Prumada` | Lista de material |
| `TB-BUSWAY-Derivacoes` | `ELT_Nivel_Origem`, `ELT_Alimenta_CM`, `ELT_Corrente_A` | Confere contra o `MAPA_NIVEIS` da rotina |
| `TB-QA-Busway-Sem-Parametro` | filtro: `ELT_Sistema` vazio | Deve ficar **zerada** após rodar o Dynamo |
| `TB-VISTAS-Controle` | Nome, `ZZ_Disciplina`, `ZZ_Subdisciplina`, `ZZ_Uso`, Folha | Gestão do próprio template |

> `TB-BUSWAY-Derivacoes` é a contraparte de conferência do dicionário `MAPA_NIVEIS`:
> ela deve listar exatamente `CM_TERREO`, `CM_APTOS_TIPO`, `CM_DUPLEX` e
> `CM_CONDOMINIO_ATICO`, um por nível. Qualquer linha a mais ou a menos é erro de inserção.

### 7.3 Legenda obrigatória

`LG-BUSWAY-SIMBOLOGIA` — replica as cores dos filtros da §2.1 com a descrição de cada uma
(prumada, derivação, redução, 1250 A, 1000 A). Sem essa legenda os filtros coloridos viram
código secreto para quem lê a prancha.

---

## 8. Ajustes na janela de Propriedades (a partir do seu print)

Sobre a vista `Planta Baixa / Térreo` que você tem aberta:

| Campo | Está | Deve ficar | Motivo |
|---|---|---|---|
| Nome da vista | `Térreo` | `ELT-BUSWAY-PL-00NA-TERREO-PR01` | §5 |
| Disciplina | `Coordenação` | `Elétrica` (em vistas de emissão) | Coordenação deixa tudo visível e sem meio-tom; para prancha ELT use Elétrica e controle o fundo por filtro |
| Escala | `1:50` | manter `1:50` | Coerente com o template `ELT-BUSWAY-Planta-Emissao` |
| Nível de detalhe | `Alto` | manter `Alto` | Busway só mostra flange/plugue em detalhe alto |
| Esquemas de sistema de cor / Estilo de análise | `CONEXÕES COM L1 - L2 INVERTIDO` | **limpar** em template de emissão | Estilo de análise sobrescreve as cores dos filtros e confunde a leitura |
| Caixa de escopo | `Nenhum` | `SC-PRUMADA-PR-01` nas vistas de prumada | Trava a extensão da vista |
| Faixa da vista | padrão | Corte no meio do pé-direito, **Profundidade da vista até a laje superior** | Garante que o trecho de busway acima do nível apareça — é exatamente o trecho que a rotina insere ("peça a inserir no trecho ACIMA do nível") |
| Sub-Disciplina (nativo) | vazio | deixar vazio; usar `ZZ_Subdisciplina` | §1.1 |
| Template de vista | (não aplicado) | `ELT-BUSWAY-Planta-Emissao` | Trava o padrão |

> O item da **Faixa da vista** é o mais crítico para busway: como o `MAPA_NIVEIS` insere a
> peça *acima* de cada nível, uma faixa de vista com profundidade curta faz a planta ficar
> vazia e dá a falsa impressão de que a rotina não rodou.

---

## 9. Checklist de fechamento do template

- [ ] Todos os parâmetros `ZZ_*` e `ELT_*` criados como compartilhados
- [ ] Esquema `99-SEM-CLASSIFICACAO` vazio
- [ ] Nenhuma vista fora do padrão de nomenclatura (confira em `TB-VISTAS-Controle`)
- [ ] Toda vista de emissão com **Template de vista atribuído** (não só aplicado)
- [ ] Tabela `TB-QA-Busway-Sem-Parametro` zerada
- [ ] Filtro `ELT-BUSWAY-SemParametro` presente em todos os templates ELT
- [ ] Caixas de escopo criadas para cada prumada
- [ ] Legenda `LG-BUSWAY-SIMBOLOGIA` na folha `ELT-BW-00`
- [ ] Vistas WIP purgadas (`Gerenciar > Purgar não utilizados`)
- [ ] Modelo salvo como **`.rte`** (`Salvar como > Template`), não como `.rvt`

---

## 10. Integração com as rotinas Dynamo deste repositório

Para que o template e a automação se sustentem mutuamente:

1. **A rotina passa a escrever os parâmetros.** Ao inserir cada peça, gravar
   `ELT_Sistema`, `ELT_Tipo_Peca`, `ELT_Corrente_A`, `ELT_Nivel_Origem`, `ELT_Alimenta_CM`
   e `ELT_Prumada` a partir do próprio `MAPA_NIVEIS`. Os dados já existem no dicionário —
   é só transferi-los para os elementos.
2. **O template verifica a rotina.** Filtro magenta + tabela de QA acusam qualquer peça
   inserida sem parâmetro, sem precisar abrir o Dynamo de novo.
3. **Nomes de nível são contrato.** As chaves do `MAPA_NIVEIS` são exatamente os nomes dos
   níveis do Revit. Renomear um nível quebra a rotina silenciosamente — trave a
   nomenclatura de níveis no template e documente isso na folha `ELT-BW-00`.
4. **Nomes de Family Type são contrato.** `Barramento-Reto`,
   `Barramento-Derivação-1 Plugue`, `Barramento-Redução-1250A-1000A` precisam existir com
   grafia idêntica no template. Deixe as três famílias **pré-carregadas** no `.rte`.
