# Análise de Tamanho de Vínculos e Fluxo de Modelagem — HB 3321 (Obra Gonçalves Dias)

> Base da análise: capturas de tela das pastas `VÍNCULOS` e `VÍNCULOS\IFC's`.
> Os arquivos não foram abertos (execução remota, sem acesso ao disco local).
> Itens marcados **[verificar]** dependem de conferência no ambiente do usuário.

---

## 1. Inventário observado

### 1.1 Pasta A (anexo 1 — "VÍNCULOS RVT")

| Arquivo | Tamanho | Tipo mostrado pelo Windows |
|---|---|---|
| 2001-EXE-ARQ-0001-MOD-R05.ifc | 125.024 KB | Autodesk Revit Project |
| 2001-EXE-ELE-0001-MOD-R04.ifc | 92.284 KB | Autodesk Revit Project |
| 2001-EXE-FOR-0020-GER-R07(26-09-24_10h17min29s).ifc | 22.756 KB | Autodesk Revit Project |
| ELET_GUIA | 92.284 KB | Autodesk Revit Project |

### 1.2 Pasta B (`VÍNCULOS\IFC's`)

| Arquivo | Tamanho | Tipo |
|---|---|---|
| 2001-EXE-ARQ-0001-MOD-R05 | 89.118 KB | IFC File |
| 2001-EXE-ARQ-0001-MOD-R05.ifc | 125.008 KB | Autodesk Revit Project |
| 2001-EXE-ARQ-0001-MOD-R05.ifc.log | 1 KB | log de importação |
| 2001-EXE-ARQ-0001-MOD-R05.ifc.shared-parameters.txt | 63 KB | parâmetros compartilhados |
| 2001-EXE-ELE-0001-MOD-R04 | 57.891 KB | IFC File |
| 2001-EXE-ELE-0001-MOD-R04.ifc | 92.280 KB | Autodesk Revit Project |
| 2001-EXE-ELE-0001-MOD-R04.ifc.shared-parameters.txt | 26 KB | — |
| 2001-EXE-FOR-0020-GER-R07(...) | 11.049 KB | IFC File |
| 2001-EXE-FOR-0020-GER-R07(...).ifc | 22.744 KB | Autodesk Revit Project |
| 2001-EXE-FOR-0020-GER-R07(...) | 38 KB | shared-parameters |

---

## 2. Achados críticos

### 2.1 `ELET_GUIA` é cópia byte-a-byte do modelo elétrico
`ELET_GUIA` = **92.284 KB**, idêntico a `2001-EXE-ELE-0001-MOD-R04.ifc` (92.284 KB) na mesma pasta.
Não é um "guia" — é uma **duplicata renomeada** do mesmo RVT-de-IFC.

Consequências:
- ~90 MB carregados duas vezes na sessão se ambos estiverem vinculados;
- dois vínculos gerando geometria sobreposta → colisões falsas, contagem dobrada em tabelas, Navisworks/Solibri acusando clash inexistente;
- risco de o usuário atualizar um e não o outro (divergência silenciosa de revisão).

**Ação:** decidir qual é o vínculo oficial, remover o outro do projeto e do CDE. Se `ELET_GUIA` serve de *base de rastreio* para modelagem (calcar caminhamento), ele deveria ser um **workset separado, desligado por padrão**, não um segundo vínculo permanente.

### 2.2 Os arquivos estão duplicados entre as duas pastas
Comparando pasta A × pasta B:

| Modelo | Pasta A | Pasta B | Δ |
|---|---|---|---|
| ARQ R05 | 125.024 KB | 125.008 KB | 16 KB |
| ELE R04 | 92.284 KB | 92.280 KB | 4 KB |
| FOR R07 | 22.756 KB | 22.744 KB | 12 KB |

Diferenças de 4–16 KB são típicas de **um "salvar" a mais** (jornal/histórico/preview atualizado), não de conteúdo diferente. Confirma: **são o mesmo conjunto, copiado em dois lugares.**

Isso é o pior cenário de vínculo: o Revit guarda o caminho absoluto (ou relativo) de *uma* das cópias. Ao atualizar a outra, o modelo continua lendo a antiga sem avisar. **Um arquivo, um caminho, uma verdade.** As demais são cópias mortas.

### 2.3 Extensão dupla `.ifc` num arquivo RVT — armadilha de nomenclatura
Todos os RVT gerados chamam-se `nome.ifc` (na verdade `nome.ifc.rvt`, com a extensão real oculta pelo Windows). Isso é o comportamento padrão do *Open IFC* do Revit, mas em produção causa:
- confusão entre origem (IFC) e derivado (RVT);
- risco de vincular o IFC nativo quando se queria o RVT (ou vice-versa);
- quebra de scripts/Dynamo que filtram por extensão.

**Ação:** renomear o derivado para `..._MOD-R05_ifc.rvt` (ou sufixo `-CONV`) e manter o IFC de origem intocado, em subpasta separada.

### 2.4 Status de sincronização do OneDrive em erro (ícone ❌)
Na captura da pasta `IFC's`, **todos** os itens mostram ❌ na coluna Status — não sincronizados. Vínculo Revit apontando para arquivo OneDrive não sincronizado é fonte clássica de:
- "não foi possível encontrar o arquivo vinculado" ao abrir em outra máquina;
- travamento na abertura enquanto o Files On-Demand baixa 90 MB;
- corrupção quando o Revit escreve enquanto o OneDrive sincroniza.

**Ação:** vínculos e centrais **nunca** em pasta com sync ativo em tempo real. Use pasta local (ou BIM 360 / ACC / Revit Server) e o OneDrive só para entregáveis fechados (PDF, IFC publicado).

### 2.5 Arquivo `FOR-0020-GER-R07(26-09-24_10h17min29s)`
O carimbo de data/hora no nome é saída automática de exportador (comum em fornecedor de barramento/eletrocalha). Duas questões:
- **Data 26-09-24** — muito anterior aos demais (mai/2026). O barramento **[verificar]** pode estar defasado em relação a ARQ R05 e ELE R04.
- Nome fora do padrão do restante (parênteses, dois pontos convertidos, timestamp). Parênteses e caracteres especiais quebram scripts e URLs de CDE.

**Ação:** renomear para o padrão `2001-EXE-FOR-0020-GER-R07.ifc` e registrar a data original em metadado/planilha de controle, não no nome.

---

## 3. IFC → RVT: o arquivo fica mais pesado ou mais leve?

**Sempre mais pesado.** Confirmado pelos seus próprios números:

| Modelo | IFC | RVT gerado | Crescimento |
|---|---|---|---|
| ARQ R05 | 89.118 KB | 125.008 KB | **+40%** |
| ELE R04 | 57.891 KB | 92.280 KB | **+59%** |
| FOR R07 | 11.049 KB | 22.744 KB | **+106%** |

### Por que engorda
O IFC é texto (STEP) — compacto, muitas vezes com geometria *implícita* (parametrizada) e reaproveitamento de instâncias. Ao abrir no Revit:
1. cada entidade IFC vira uma **família genérica `.rfa` embutida** no projeto (uma família por tipo de sólido, às vezes por *instância*);
2. a geometria é convertida em **DirectShape / sólidos explícitos** — malhas com todos os vértices materializados;
3. todo o conjunto de propriedades IFC (`Psets`) é reescrito como **parâmetros compartilhados** — daí os arquivos `.shared-parameters.txt` de 63 KB e 26 KB ao lado;
4. entram ainda estruturas próprias do RVT: jornal interno, thumbnail, materiais, histórico.

### O formato/flavor do IFC impacta — e muito

| Fator no IFC | Efeito no RVT gerado |
|---|---|
| **IFC2x3 CV2.0 × IFC4 Reference View** | IFC4 RV é *tesselado* (`IfcTriangulatedFaceSet`) → vira malha densa no Revit, mais pesado e não editável. IFC2x3 CV2.0 costuma preservar mais B-Rep/extrusão → RVT mais leve e mais "limpo". |
| **Design Transfer View (IFC4 DTV)** | Preserva geometria paramétrica; é o único flavor pensado para *re-editar*. Gera RVT mais leve que RV, mas suporte irregular entre softwares. |
| **Coordination View 2.0** | Melhor custo/benefício para vínculo de coordenação (que é o seu caso). |
| **B-Rep × Extrusão/Swept Solid** | B-Rep explode o tamanho. Exportador que preserva extrusões reduz o RVT em dezenas de %. |
| **Nível de detalhe / mobiliário / hardware** | Puxadores, louças detalhadas, vegetação: dominam o peso e são inúteis para o elétrico. |
| **Psets exportados** | Exportar "todos os Psets + quantidades" infla o `.shared-parameters` e o RVT. Para vínculo, exportar o mínimo. |
| **Geometria por camada/nível filtrada** | Exportar só os pavimentos de interesse reduz proporcionalmente. |

**Regra prática para o seu fluxo:** o crescimento de +40% a +106% que você observou é normal. O que você controla é o *insumo*: peça à arquitetura um IFC **2x3 Coordination View 2.0**, sem mobiliário/paisagismo, com Psets mínimos. Isso reduz o RVT final bem mais do que qualquer purge posterior.

---

## 4. RVT-de-IFC × IFC vinculado direto: qual usar

| Critério | Vincular o **IFC** direto | Vincular o **RVT** convertido |
|---|---|---|
| Peso em RAM | Revit converte na abertura toda vez (lento a cada abertura) | Conversão feita uma vez |
| Tempo de abertura | Alto e repetido | Baixo após a primeira |
| Purge possível | Não | **Sim** — ganho real de 20–40% |
| Worksets no vínculo | Não | Sim (permite descarregar partes) |
| Atualização de revisão | Reload direto | Reconverter e substituir |
| Estabilidade | Menor | Maior |

**Recomendado (é o que você já faz — está correto):** converter para RVT uma vez, **purgar e tratar**, e vincular o RVT. Só falta o tratamento pós-conversão.

### Tratamento pós-conversão (o passo que falta no seu fluxo)
Abrir cada RVT gerado e, antes de usar como vínculo:
1. `Purge Unused` **3 vezes seguidas** (a primeira nunca pega tudo);
2. deletar vistas, folhas e tabelas importadas que não serão usadas;
3. apagar categorias irrelevantes ao elétrico (mobiliário, paisagismo, sanitários detalhados) via filtro de seleção;
4. remover *pattern* e materiais órfãos;
5. criar **worksets por disciplina/pavimento** dentro do vínculo, para poder descarregar sob demanda;
6. `Save As` com compactação (`Compact File` marcado);
7. definir **Shared Coordinates** (item 5 abaixo);
8. medir: espera-se cair de 125 MB para algo entre **60–85 MB** no caso da ARQ.

---

## 5. Posicionamento ARQ × ELET × BARRAMENTO

Pelo que a estrutura mostra, os três vínculos são carregados no mesmo nível, presumivelmente por `Auto – Origin to Origin` **[verificar]**. Isso funciona só enquanto todos vierem da mesma origem — e o barramento, exportado por fornecedor com timestamp próprio, é justamente o que tende a fugir.

**Método correto, na ordem:**
1. **ARQ é a referência mestra.** Ela define o ponto de levantamento e o ponto-base do projeto.
2. Vincular a ARQ por `Origin to Origin`, posicionar corretamente e **`Acquire Coordinates`** a partir dela.
3. Elétrico e barramento vinculados por **`Auto – By Shared Coordinates`**. Se o modelo do fornecedor não tiver coordenada compartilhada, posicionar manualmente uma vez e **`Publish Coordinates`** para ele.
4. **Pinar todos os vínculos** (`Pin`) imediatamente após posicionar. Vínculo despinado é a causa nº 1 de deslocamento acidental.
5. Registrar em planilha de controle: cada vínculo, sua revisão, seu método de posicionamento e a data.

**Risco específico do barramento:** modelo de fornecedor datado de 26/09/24 contra arquitetura de 18/05/26. Além do desalinhamento geométrico possível, há ~20 meses de mudanças de arquitetura não refletidas. **Verificar se o R07 ainda é a revisão vigente antes de coordenar.**

---

## 6. Pasta REFERÊNCIAS (PDFs de planta baixa)

Não foi possível abrir os PDFs. O que deve ser verificado, item a item:

| Verificação | Como conferir |
|---|---|
| **Revisão** | O PDF corresponde a ARQ **R05**? PDF de R03/R04 contra modelo R05 gera modelagem sobre informação morta. |
| **Escala** | Medir uma cota conhecida no PDF (vão de porta, eixo a eixo) contra o RVT. PDF exportado com "ajustar à página" perde escala. |
| **Origem/rotação** | O PDF vinculado no Revit precisa ser alinhado ao mesmo eixo do modelo, não "no olho". |
| **Nível/pavimento** | Cada PDF deve estar vinculado à vista de planta do pavimento correto. |
| **Peso** | PDF vetorial é leve; PDF *rasterizado* (scan/imagem) pesa e trava o pan/zoom. Se for raster, ele deve ser removido após a modelagem. |

**Recomendação:** PDF é apoio temporário. Uma vez que a ARQ está disponível em RVT e IFC, **a geometria 3D é a fonte de verdade**; o PDF serve só para ler texto/anotação que não veio no modelo. Manter PDFs vinculados permanentemente degrada performance e cria risco de modelar sobre revisão antiga. Vincular → modelar → **remover o vínculo PDF**.

---

## 7. Estrutura de pastas CDE recomendada (ISO 19650)

A ISO 19650 define quatro **estados** de informação: `WIP → SHARED → PUBLISHED → ARCHIVE`. A estrutura abaixo aplica isso ao ambiente de disco/nuvem de um escritório de projetos.

```
HB3321-Gonçalves-Dias/
├─ 00-WIP/                          # Trabalho em progresso — só a equipe da disciplina
│  ├─ ELE/
│  │  ├─ MOD/                       # centrais Revit
│  │  ├─ FAM/                       # famílias em desenvolvimento
│  │  └─ DYN/                       # rotinas Dynamo
│  └─ _TEMP/
│
├─ 01-SHARED/                       # Compartilhado — coordenação entre disciplinas
│  ├─ ARQ/
│  │  ├─ IFC/                       # IFC recebido, original, intocado
│  │  ├─ RVT/                       # RVT convertido/purgado (o que se vincula)
│  │  └─ PDF/
│  ├─ ELE/
│  ├─ EST/
│  ├─ HID/
│  ├─ FOR/                          # modelos de fornecedor (barramento, eletrocalha)
│  └─ _COORD/                       # modelos federados, relatórios de clash
│
├─ 02-PUBLISHED/                    # Aprovado para uso/construção
│  ├─ R05/
│  │  ├─ IFC/
│  │  ├─ PDF/
│  │  └─ DWG/
│  └─ R06/
│
├─ 03-ARCHIVE/                      # Revisões superadas, somente leitura
│  └─ 2026-05-18_R04/
│
└─ 04-RESOURCES/                    # Recursos do escritório
   ├─ TEMPLATES/
   ├─ BIBLIOTECA/
   ├─ NORMAS/
   └─ REFERENCIAS/                  # PDFs de apoio, levantamentos
```

### Mapeamento do que você tem hoje
| Hoje | Deveria estar em |
|---|---|
| `VÍNCULOS\IFC's\*.ifc` (IFC nativo) | `01-SHARED/ARQ/IFC/`, `01-SHARED/ELE/IFC/`, `01-SHARED/FOR/IFC/` |
| `VÍNCULOS\IFC's\*.ifc.rvt` (convertido) | `01-SHARED/<DISC>/RVT/` |
| `VÍNCULOS RVT\*` (cópia duplicada) | **eliminar** — é duplicata |
| `ELET_GUIA` | eliminar ou virar workset dentro do vínculo ELE |
| `REFERÊNCIAS\*.pdf` | `04-RESOURCES/REFERENCIAS/` ou `01-SHARED/ARQ/PDF/` |
| `*.shared-parameters.txt`, `*.log` | `00-WIP/_TEMP/` — subproduto de conversão, não é entregável |

### Nomenclatura de arquivo
O padrão que você já usa está correto e é compatível com ISO 19650:

```
2001 - EXE - ARQ - 0001 - MOD - R05 . ifc
 │      │     │      │      │     │
 │      │     │      │      │     └─ Revisão
 │      │     │      │      └─────── Tipo (MOD/DES/REL/GER)
 │      │     │      └────────────── Número sequencial
 │      │     └───────────────────── Disciplina (ARQ/ELE/EST/HID/FOR)
 │      └─────────────────────────── Fase (EXE/EXC/BAS/ANT)
 └────────────────────────────────── Projeto
```

Correções pontuais: usar sempre `ELE` (nunca alternar com `ELET`), eliminar parênteses e timestamps do nome, e sufixar o derivado de IFC com `_ifc` ou `-CONV`.

---

## 8. Ganhos de performance no Revit — por ordem de impacto

1. **Eliminar a duplicata `ELET_GUIA`** → −90 MB de carga imediata. Maior ganho, custo zero.
2. **Purgar os RVT convertidos** (3× + compactar) → −20% a −40% em cada vínculo. Nos 240 MB atuais, algo como 60–90 MB.
3. **Sair do OneDrive sincronizado** → elimina travamentos e vínculos quebrados. Pasta local ou ACC.
4. **Worksets nos vínculos** → carregar só o pavimento/setor em que se está trabalhando.
5. **Vincular RVT, nunca IFC direto** (já é o que você faz — manter).
6. **Pedir IFC mais magro à arquitetura** (IFC2x3 CV2.0, sem mobiliário/paisagismo, Psets mínimos) → age na raiz do problema.
7. **Descarregar vínculos ao fechar** (`Manage Links → Unload`) e recarregar sob demanda.
8. **Remover vínculos PDF** após a modelagem.
9. **Substituir vínculos por *overlay*, não *attachment***, para não propagar em cadeia se o modelo virar vínculo de terceiros.
10. **Vistas com Detail Level = Coarse** e vínculos em *Halftone* durante a modelagem.

**Projeção:** dos ~240 MB de vínculos hoje carregados (ou ~330 MB com a duplicata), o conjunto tratado deve ficar em torno de **130–160 MB** — sem perder informação de coordenação.

---

## 9. Checklist de verificação local

- [ ] `ELET_GUIA` e `2001-EXE-ELE-0001-MOD-R04.ifc` têm hash idêntico? (`certutil -hashfile <arquivo> MD5`)
- [ ] Ambos estão vinculados simultaneamente no modelo elétrico? (`Manage → Manage Links`)
- [ ] Os vínculos apontam para `VÍNCULOS RVT` ou para `VÍNCULOS\IFC's`? Qual pasta é a viva?
- [ ] Caminho do vínculo é absoluto ou relativo? (Absoluto quebra em outra máquina.)
- [ ] Todos os vínculos estão *pinados*?
- [ ] Método de posicionamento: Origin to Origin ou Shared Coordinates?
- [ ] `FOR-0020-GER-R07` de 26/09/24 ainda é a revisão vigente do barramento?
- [ ] Os PDFs de REFERÊNCIAS são da revisão R05 da arquitetura?
- [ ] Os PDFs estão em escala 1:1 quando medidos contra o RVT?
- [ ] Status de sincronização do OneDrive resolvido (sem ❌)?
- [ ] Cada RVT convertido já passou por Purge + Compact?
