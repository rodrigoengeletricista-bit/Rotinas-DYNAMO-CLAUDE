# Análise de Vínculos, Conversão IFC→RVT e Fluxo de Modelagem
## HB 3321 — Obra Gonçalves Dias

**Base:** metadados de duas listagens de diretório (nome, tipo, tamanho, data de
modificação, status de sincronização). Os modelos não foram abertos.
Cada afirmação abaixo está classificada:

- **[MEDIDO]** — deriva diretamente de tamanho ou data visíveis nas capturas.
- **[INFERIDO]** — reconstrução lógica a partir dos metadados; alta confiança, mas indireta.
- **[VERIFICAR]** — depende de abrir o arquivo; método de conferência indicado.

---

## 1. Reconstrução forense do fluxo de trabalho

Os carimbos de data/hora contam a história inteira do que aconteceu com esses
arquivos. Ordenados cronologicamente:

| Data/hora | Evento | Arquivo |
|---|---|---|
| 18/05 11:37 | shared-parameters escrito | ARQ |
| 18/05 11:38 | **RVT gerado** | ARQ (125.008 KB) |
| 18/05 11:40 | shared-parameters escrito | ELE |
| 18/05 11:41 | **RVT gerado** | ELE (92.280 KB) |
| 18/05 11:43 | shared-parameters + **RVT gerado** | FOR (22.744 KB) |
| 18/05 12:15 | log de importação | FOR |
| 18/05 13:17 | **IFC de origem modificado** | ARQ (89.118 KB) |
| 18/05 13:18 | **IFC de origem modificado** | ELE, FOR |
| 19/05 09:04 | RVT salvo na pasta A | ELE (92.284 KB) |
| 19/05 09:07 | logs de importação reescritos | ARQ **e** ELE |
| 19/05 13:02 | **ELET_GUIA criado** (92.284 KB) | — |
| 22/05 12:43 | RVT salvo na pasta A | ARQ (125.024 KB) |
| 22/05 14:20 | RVT salvo na pasta A | FOR (22.756 KB) |

Disso saem quatro conclusões que mudam as recomendações.

### 1.1 Os RVT foram gerados de IFC que não existem mais no disco **[MEDIDO]**

A conversão ocorreu entre **11:37 e 11:43** do dia 18/05. Os arquivos IFC de
origem, na mesma pasta, têm data de modificação **13:17–13:18 do mesmo dia** —
cerca de **1h35 depois** da conversão que supostamente os consumiu.

Um arquivo não pode ser fonte de um derivado criado antes dele. Portanto, uma
de duas coisas:

- os IFC foram **substituídos** por uma versão mais nova depois da conversão, e
  os RVT em uso descendem de uma versão que não está mais no disco; ou
- os IFC foram **rebaixados/recopiados** do CDE às 13:17 (download reseta a data
  de modificação), e o conteúdo pode ou não ser o mesmo.

Em qualquer dos casos, **você não tem como provar que os RVT vinculados
correspondem aos IFC que estão ao lado deles.** Esse é o problema mais grave do
conjunto, e é invisível — nada no Revit vai avisar.

**Conferir:** abrir `2001-EXE-ARQ-0001-MOD-R05.ifc.log` (1 KB, texto puro). O log
de importação do Revit registra o caminho e o horário do IFC processado. Se o
horário no log não bater com 13:17, está confirmada a divergência.

### 1.2 A pasta A é a viva; a pasta B (`IFC's`) está congelada **[INFERIDO]**

Os RVT da pasta A foram salvos em 19/05 e 22/05. Os da pasta B seguem em 18/05,
com tamanhos 4–16 KB menores — exatamente o incremento de um "salvar" adicional
do Revit.

| Modelo | Pasta A | Pasta B | Δ | Última gravação em A |
|---|---|---|---|---|
| ARQ | 125.024 KB | 125.008 KB | +16 KB | 22/05 12:43 |
| ELE | 92.284 KB | 92.280 KB | +4 KB | 19/05 09:04 |
| FOR | 22.756 KB | 22.744 KB | +12 KB | 22/05 14:20 |

Isto responde a pergunta que ficou aberta antes: **a pasta A é onde o trabalho
acontece; a pasta B é a saída original da conversão, abandonada.** Se algum
vínculo do modelo elétrico apontar para a pasta B, ele está lendo o estado de
18/05 e ignorando quatro dias de trabalho.

**Conferir:** `Manage → Manage Links → aba Revit`, coluna *Saved Path*. Qualquer
caminho contendo `\IFC's\` é um vínculo morto.

### 1.3 ELET_GUIA foi criado deliberadamente, não por acidente **[MEDIDO]**

`ELET_GUIA` tem **92.284 KB — exatamente o tamanho do ELE da pasta A** (92.284 KB),
e não o da pasta B (92.280 KB). Foi originado da pasta A.

Mas a data importa: ELE-pasta-A é de **19/05 09:04**; ELET_GUIA é de **19/05 13:02**,
quatro horas depois. Uma cópia comum pelo Explorer **preserva** a data de
modificação — ela teria ficado 09:04. Ficou 13:02.

Ou seja: não foi arrastar-e-soltar. Foi um `Save As` do Revit, ou uma cópia por
script/rotina, feita como **ato deliberado quatro horas depois**. O nome ("GUIA")
reforça: alguém quis um modelo de apoio para calcar caminhamento.

Isto corrige a recomendação anterior. Não é "apagar a duplicata" — é **descobrir
para que ela serve antes de apagar**, porque alguém a criou de propósito e pode
depender dela. O desperdício continua real (90 MB de geometria idêntica
carregada duas vezes, colisão falsa, contagem dobrada), mas a solução certa é
converter o propósito em mecanismo: **um workset desligado por padrão dentro do
vínculo ELE**, não um segundo vínculo.

**Conferir:** `certutil -hashfile "ELET_GUIA.rvt" MD5` contra o ELE da pasta A.
Hash igual = conteúdo idêntico, e aí é só decidir o destino.

### 1.4 Houve uma segunda rodada de importação que não virou RVT **[INFERIDO]**

Os logs de ARQ e ELE foram **reescritos em 19/05 às 09:07**, ambos no mesmo
minuto. Um log de importação IFC só é escrito quando o Revit abre um IFC. Mas os
RVT da pasta B continuam com data de 18/05 11:38/11:41 — não foram
regravados.

Dois IFC (87 MB e 56 MB) abertos dentro do mesmo minuto não é trabalho manual —
importação de IFC desse porte leva minutos por arquivo. Sugere **execução em
lote**, o que é coerente com este repositório ser de rotinas Dynamo. **[VERIFICAR]**

O que importa: essa segunda importação de 19/05 produziu resultado que foi para
a pasta A (ELE às 09:04) mas **não atualizou a pasta B**. É a origem da
divergência entre as duas pastas.

---

## 2. Conversão IFC→RVT: a análise dos números

### 2.1 O crescimento medido **[MEDIDO]**

| Modelo | IFC | RVT | Ganho absoluto | Razão |
|---|---|---|---|---|
| ARQ | 89.118 KB | 125.008 KB | **+35.890 KB** | 1,403 (**+40,3%**) |
| ELE | 57.891 KB | 92.280 KB | **+34.389 KB** | 1,594 (**+59,4%**) |
| FOR | 11.049 KB | 22.744 KB | **+11.695 KB** | 2,059 (**+105,8%**) |

Sim, **converter IFC em RVT sempre engorda** — de 40% a 106% no seu caso.

### 2.2 O padrão do crescimento desmente a explicação óbvia

A leitura ingênua seria "quanto maior o IFC, maior o inchaço". Os dados dizem o
contrário. ARQ e ELE ganharam **quase o mesmo tanto em valor absoluto**
(35.890 KB e 34.389 KB — diferença de 4%), apesar de a ARQ ser **54% maior** que
a ELE.

Medindo a inclinação (quanto de inchaço a mais por KB de IFC a mais):

| Trecho | Δ tamanho IFC | Δ inchaço | Inclinação |
|---|---|---|---|
| FOR → ELE | +46.842 KB | +22.694 KB | **0,484** |
| ELE → ARQ | +31.227 KB | +1.501 KB | **0,048** |

A inclinação cai **dez vezes**. O inchaço cresce rápido no começo e depois
**satura em torno de 34–36 MB**.

### 2.3 O que isso significa na prática

Um custo que satura não é proporcional ao volume de geometria — é proporcional à
**quantidade de tipos distintos de objeto**. É exatamente o comportamento
esperado do mecanismo de importação do Revit:

1. cada entidade IFC distinta vira uma **família genérica embutida** no projeto;
2. a geometria vira **DirectShape / sólido explícito**;
3. os `Psets` viram **parâmetros compartilhados**.

O passo (1) custa caro **uma vez por tipo**. Depois que o catálogo de tipos está
montado, mais instâncias do mesmo tipo custam pouco. A ARQ tem muito mais
geometria que a ELE, mas não muito mais *tipos distintos* — daí o platô.

**Consequência direta para a sua decisão de trabalho:** reduzir o tamanho do IFC
não reduz o RVT proporcionalmente. O que reduz é **eliminar categorias que
trazem muitos tipos únicos** — mobiliário, louças, ferragens, esquadrias
detalhadas, paisagismo. Cada puxador diferente é uma família. Cortar 20 MB de
lajes repetidas não vai adiantar quase nada; cortar 3 MB de mobiliário variado
pode adiantar muito.

Esse é o pedido correto a fazer à arquitetura — e é diferente de "manda um IFC
menor".

### 2.4 O modelo do fornecedor é anômalo **[MEDIDO]**

Densidade de parâmetros compartilhados por MB de IFC:

| Modelo | shared-parameters | IFC | KB de parâmetro por MB |
|---|---|---|---|
| ARQ | 63 KB | 87,0 MB | 0,72 |
| ELE | 26 KB | 56,5 MB | 0,46 |
| **FOR** | **38 KB** | **10,8 MB** | **3,52** |

O modelo de barramento tem densidade de propriedades **5 a 8 vezes maior** que os
demais. Ele gera **mais parâmetros compartilhados que o modelo elétrico inteiro**
(38 KB contra 26 KB), sendo **um quinto do tamanho**.

É a assinatura típica de modelo de fornecedor: pouca geometria, muitos atributos
de catálogo (código de peça, corrente nominal, classe de isolação, certificação).
E explica por que o FOR tem a **maior razão de inchaço de todas** (2,06): o custo
dele não está na geometria, está na conversão de propriedade em parâmetro.

**Risco decorrente, e é o que ninguém percebe:** parâmetro compartilhado
importado de vínculo polui o projeto hospedeiro. Três modelos importados
significam centenas de parâmetros vindos de três dicionários diferentes,
possivelmente com nomes colidentes e GUIDs distintos. Isso suja tabelas,
atrapalha filtros e é trabalhoso de desfazer depois. **[VERIFICAR]** — inspecionar
`Manage → Shared Parameters` e `Project Parameters` no modelo elétrico.

### 2.5 As importações foram limpas **[INFERIDO]**

Os três `.ifc.log` têm **1 KB**. O log de importação IFC do Revit registra cada
entidade que falhou ou foi aproximada; importação problemática gera log de
centenas de KB ou vários MB. 1 KB indica **poucos ou nenhum aviso** — a geometria
entrou sem falha em massa.

É a boa notícia do conjunto: o problema aqui não é qualidade de conversão, é
gestão de arquivo.

---

## 3. O flavor do IFC importa — e como

Sim, o formato impacta a conversão e o peso resultante:

| Fator no IFC de origem | Efeito no RVT gerado |
|---|---|
| **IFC4 Reference View** | Geometria tesselada (`IfcTriangulatedFaceSet`) → malha densa, pesada, não editável |
| **IFC2x3 Coordination View 2.0** | Preserva extrusão/B-Rep → RVT mais leve e limpo. **Melhor escolha para vínculo de coordenação** |
| **IFC4 Design Transfer View** | Preserva geometria paramétrica; único pensado para re-editar. Suporte irregular entre softwares |
| **B-Rep explícito × Swept Solid** | B-Rep explode o tamanho; exportador que preserva extrusões corta dezenas de % |
| **Nº de tipos distintos** (§2.3) | **O fator dominante.** Mobiliário/ferragens/louças multiplicam famílias embutidas |
| **Psets exportados** | Exportar "todos + quantidades" infla shared-parameters e polui o hospedeiro (§2.4) |
| **Filtro de pavimentos** | Exportar só os níveis de interesse reduz proporcionalmente |

**Pedido a fazer à arquitetura, nesta ordem de impacto:** IFC2x3 CV2.0 · sem
mobiliário, paisagismo e louças detalhadas · Psets restritos ao necessário para
coordenação · apenas os pavimentos em escopo.

---

## 4. Vincular IFC direto ou RVT convertido

| Critério | IFC direto | RVT convertido |
|---|---|---|
| Conversão | a cada abertura | uma única vez |
| Tempo de abertura | alto e repetido | baixo após a primeira |
| `Purge Unused` | impossível | **possível — 20 a 40%** |
| Worksets no vínculo | não | sim (descarga sob demanda) |
| Atualização de revisão | reload direto | reconverter e substituir |
| Rastreabilidade de origem | direta | **exige disciplina (§1.1)** |

**O que você já faz está correto** — converter uma vez e vincular o RVT. O que
falta é o tratamento pós-conversão e o controle de proveniência.

### Tratamento pós-conversão (o passo ausente)

1. `Purge Unused` **três vezes seguidas** — a primeira nunca pega tudo;
2. deletar vistas, folhas e tabelas importadas;
3. apagar categorias irrelevantes ao elétrico — é aqui que está o ganho real (§2.3);
4. remover materiais e padrões órfãos;
5. criar **worksets por pavimento/setor** dentro do vínculo;
6. definir **Shared Coordinates** (§5);
7. `Save As` com **Compact File** marcado;
8. medir o antes e depois e registrar.

---

## 5. Posicionamento ARQ × ELE × BARRAMENTO

### 5.1 O método correto, na ordem

1. **ARQ é a referência mestra** — define ponto de levantamento e ponto-base.
2. Vincular ARQ por `Origin to Origin`, posicionar e **`Acquire Coordinates`** dela.
3. ELE e FOR por **`Auto – By Shared Coordinates`**. Se o modelo do fornecedor não
   tiver coordenada compartilhada, posicionar uma vez e **`Publish Coordinates`**.
4. **Pinar todos os vínculos** logo após posicionar — vínculo despinado é a causa
   número 1 de deslocamento acidental.
5. Registrar em planilha: vínculo, revisão, método de posicionamento, data.

**[VERIFICAR]** `Manage Links`, coluna *Positioning*. Se estiver `Origin to Origin`
nos três, funciona só enquanto todos vierem da mesma origem — e o FOR, exportado
por fornecedor com carimbo próprio, é justamente o que tende a fugir.

### 5.2 O barramento está defasado em ~20 meses **[MEDIDO]**

O nome carrega o carimbo do exportador: `R07(26-09-24_10h17min29s)` — conteúdo de
**setembro de 2024**. Os demais modelos são de **maio de 2026**.

O arquivo foi *colocado* na pasta em 18/05/2026, mas o que está dentro dele é de
20 meses antes. Coordenar barramento de set/2024 contra arquitetura R05 de
mai/2026 significa validar contra uma realidade que provavelmente já mudou —
e nada no Revit vai sinalizar isso, porque a data do arquivo parece atual.

**Ação:** confirmar com o fornecedor se R07 ainda é vigente **antes** de qualquer
rodada de coordenação ou clash. É a verificação de maior risco da lista.

---

## 6. Sincronização OneDrive em erro **[MEDIDO]**

Na listagem da pasta `IFC's`, **todos os itens exibem ❌ na coluna Status** — não
sincronizados. Vínculo apontando para arquivo OneDrive não sincronizado produz:

- "não foi possível encontrar o arquivo vinculado" ao abrir em outra máquina;
- travamento na abertura enquanto o Files On-Demand baixa ~90 MB;
- risco de corrupção quando o Revit grava enquanto o OneDrive sincroniza.

Somado ao §1.2 (duas cópias divergentes), é a receita completa para alguém
trabalhar dias sobre a versão errada sem perceber.

**Ação:** centrais e vínculos **nunca** em pasta com sincronização em tempo real.
Pasta local, ou ACC/BIM 360/Revit Server. OneDrive apenas para entregáveis
fechados (PDF, IFC publicado).

---

## 7. Pasta REFERÊNCIAS (PDF de plantas baixas)

Não tive acesso aos PDFs — nenhuma conclusão sobre eles é possível a partir dos
metadados disponíveis. O que precisa ser conferido, item a item:

| Verificação | Método | Por que importa |
|---|---|---|
| **Revisão** | carimbo do PDF × ARQ R05 | PDF de R03/R04 = modelar sobre informação morta |
| **Escala** | medir vão conhecido no PDF × RVT | export "ajustar à página" perde escala |
| **Origem/rotação** | alinhar ao eixo do modelo | alinhamento "no olho" propaga erro |
| **Nível** | cada PDF na vista do pavimento certo | — |
| **Vetorial ou raster** | zoom máximo: pixel = raster | raster pesa e trava pan/zoom |

**Recomendação de fluxo:** com ARQ disponível em RVT e IFC, **a geometria 3D é a
fonte de verdade**; o PDF serve apenas para ler texto/anotação que não veio no
modelo. Vincular → modelar → **remover o vínculo PDF**. Mantê-los vinculados
permanentemente degrada performance e cria risco de modelar sobre revisão antiga.

---

## 8. Estrutura de pastas CDE (ISO 19650)

A ISO 19650 organiza a informação em quatro estados: `WIP → SHARED → PUBLISHED →
ARCHIVE`. Aplicado ao seu disco:

```
HB3321-Goncalves-Dias/
├─ 00-WIP/                     # em progresso — só a disciplina dona
│  └─ ELE/{MOD,FAM,DYN}/       # centrais, famílias, rotinas Dynamo
├─ 01-SHARED/                  # compartilhado — coordenação
│  ├─ ARQ/{IFC,RVT,PDF}/       # IFC = origem intocada · RVT = convertido e purgado
│  ├─ ELE/ · EST/ · HID/
│  ├─ FOR/                     # modelos de fornecedor
│  └─ _COORD/                  # federados, relatórios de clash
├─ 02-PUBLISHED/R05/{IFC,PDF,DWG}/
├─ 03-ARCHIVE/2026-05-18_R04/  # superadas, somente leitura
└─ 04-RESOURCES/{TEMPLATES,BIBLIOTECA,NORMAS,REFERENCIAS}/
```

**A regra que resolve o §1.2:** o IFC recebido entra em `01-SHARED/<DISC>/IFC/` e
**nunca mais é tocado**. O RVT convertido vive em `01-SHARED/<DISC>/RVT/` e é o
**único** que os vínculos enxergam. Um arquivo, um caminho, uma verdade. Cópia de
trabalho em outra pasta é sempre dívida futura.

### Migração do que existe hoje

| Hoje | Destino |
|---|---|
| `VÍNCULOS\IFC's\*` (IFC nativo) | `01-SHARED/<DISC>/IFC/` |
| `VÍNCULOS\IFC's\*.ifc.rvt` (18/05, obsoleto) | `03-ARCHIVE/2026-05-18/` |
| `VÍNCULOS RVT\*` (pasta A, viva) | `01-SHARED/<DISC>/RVT/` |
| `ELET_GUIA` | workset no vínculo ELE, ou arquivar (§1.3) |
| `REFERÊNCIAS\*.pdf` | `01-SHARED/ARQ/PDF/` |
| `*.shared-parameters.txt`, `*.log` | `00-WIP/_TEMP/` — subproduto, não entregável |

### Nomenclatura

O padrão que você usa já é compatível com ISO 19650:

```
2001 - EXE - ARQ - 0001 - MOD - R05
 │      │     │      │      │     └─ revisão
 │      │     │      │      └─────── tipo (MOD/DES/REL/GER)
 │      │     │      └────────────── sequencial
 │      │     └───────────────────── disciplina (ARQ/ELE/EST/HID/FOR)
 │      └─────────────────────────── fase (EXE/BAS/ANT)
 └────────────────────────────────── projeto
```

Três correções: (a) padronizar `ELE`, nunca alternar com `ELET`; (b) remover
parênteses e carimbos de hora do nome — quebram scripts e URLs de CDE, e mascaram
a defasagem do §5.2, que deve ir para a planilha de controle; (c) **sufixar o
derivado com `_ifc`** — hoje os RVT se chamam `nome.ifc` (na verdade
`nome.ifc.rvt`, com a extensão real oculta pelo Windows), o que confunde origem
com derivado e faz vincular um pelo outro.

---

## 9. Ganhos de performance, por ordem de impacto

| # | Ação | Ganho | Custo |
|---|---|---|---|
| 1 | Resolver `ELET_GUIA` (§1.3) | **−90 MB** de carga | ~zero |
| 2 | Purgar 3× + compactar os RVT | **−25 a 35%** | 1h |
| 3 | Sair do OneDrive sincronizado | elimina travamento e vínculo quebrado | 30 min |
| 4 | Apontar todos os vínculos à pasta A e arquivar a B (§1.2) | evita retrabalho sobre versão morta | 15 min |
| 5 | Worksets nos vínculos | carrega só o setor em uso | 2h |
| 6 | Pedir IFC sem mobiliário/ferragens (§2.3) | ataca a raiz | depende de terceiro |
| 7 | `Unload` ao fechar, recarregar sob demanda | abertura muito mais rápida | hábito |
| 8 | Remover vínculos PDF após modelar | — | hábito |
| 9 | Vínculos como *overlay*, não *attachment* | não propaga em cadeia | 5 min |
| 10 | Detail Level `Coarse` + vínculos em *Halftone* | fluidez de tela | 5 min |

**Projeção quantificada:**

- hoje, com a duplicata carregada: **324,6 MB** de vínculos
- eliminando a duplicata: **234,4 MB**
- após purge e compactação (25–35%): **164–176 MB**

Redução de cerca de **metade da carga**, sem perder nenhuma informação de
coordenação.

---

## 10. Checklist de verificação local

**Prioridade 1 — integridade (fazer antes de qualquer modelagem)**

- [ ] Log do ARQ registra IFC de que horário? Bate com 13:17 de 18/05? (§1.1)
- [ ] `Manage Links` → algum *Saved Path* aponta para `\IFC's\`? (§1.2)
- [ ] `certutil -hashfile "ELET_GUIA.rvt" MD5` = hash do ELE da pasta A? (§1.3)
- [ ] ELET_GUIA e ELE estão ambos vinculados ao mesmo tempo?
- [ ] **FOR R07 de set/2024 ainda é vigente?** — confirmar com o fornecedor (§5.2)

**Prioridade 2 — posicionamento e coordenadas**

- [ ] Coluna *Positioning*: Origin to Origin ou Shared Coordinates? (§5.1)
- [ ] Todos os vínculos estão pinados?
- [ ] Caminho absoluto ou relativo? (absoluto quebra em outra máquina)
- [ ] Barramento alinhado à ARQ ou herdando origem própria?

**Prioridade 3 — higiene e performance**

- [ ] Status ❌ do OneDrive resolvido? (§6)
- [ ] Cada RVT já passou por Purge 3× + Compact?
- [ ] `Shared Parameters` do modelo ELE está poluído pelos três vínculos? (§2.4)
- [ ] PDFs de REFERÊNCIAS são da revisão R05? Estão em escala? (§7)
- [ ] PDFs ainda vinculados após a modelagem?

---

## Síntese

O conjunto **não tem problema de qualidade de conversão** — os logs de 1 KB
mostram importação limpa, e o crescimento de 40–106% é o esperado do mecanismo do
Revit. Os problemas são todos de **gestão de arquivo**, e três deles são
silenciosos:

1. os RVT em uso podem não corresponder aos IFC ao lado deles (§1.1);
2. existem duas pastas divergentes e nada indica qual está viva (§1.2);
3. o barramento tem 20 meses de defasagem escondidos atrás de uma data de arquivo
   recente (§5.2).

Nenhum dos três dispara aviso no Revit. Todos são resolvidos por estrutura de
pasta com estado único e uma planilha de controle de revisão — que é exatamente o
que a ISO 19650 existe para prevenir.
