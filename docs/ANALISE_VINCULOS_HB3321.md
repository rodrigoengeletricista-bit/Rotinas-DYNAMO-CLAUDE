# Análise de Tamanho de Vínculos — HB 3321 / OBRA Gonçalves Dias

> **Escopo dos dados**: esta análise foi feita a partir das capturas de tela da pasta
> `VERIFICAÇÃO DE MODELOS\HB 3321 - OBRA Gonçaves Dias\VÍNCULOS\IFC's`.
> O caminho local (`C:\Users\RODRIGO\OneDrive\...`) não é acessível a partir desta
> sessão remota, então os números abaixo são os exibidos no Explorer.

---

## 1. Inventário e relação IFC → RVT

| Modelo | IFC | RVT (convertido) | Fator RVT/IFC | .shared.txt |
|---|---:|---:|---:|---:|
| 2001-EXE-**ARQ**-0001-MOD-R05 | 89.118 KB (~87 MB) | **125.008 KB (~122 MB)** | **1,40×** | 63 KB |
| 2001-EXE-**ELE**-0001-MOD-R04 | 57.891 KB (~57 MB) | **92.280 KB (~90 MB)** | **1,59×** | 26 KB |
| 2001-EXE-**FOR**-0020-GER-R07 (barramento) | 11.049 KB (~11 MB) | **22.744 KB (~22 MB)** | **2,06×** | 38 KB |

**Conclusão direta da pergunta "fica mais leve ou mais pesado?":**
o RVT gerado a partir de IFC é **sempre mais pesado** — aqui entre **1,4× e 2,1×** o IFC de origem.
Não houve nenhum caso de redução.

Sobre "os dois RVT parecem ter o mesmo tamanho" (anexo 1): eles **não são iguais**
(122 MB × 90 MB). O que se repete é a *proporção*: cada RVT cresce em relação ao seu
próprio IFC dentro da mesma faixa. Isso é assinatura de conversão automática, não de
modelagem nativa.

### Por que o RVT engorda
1. O `Open IFC` cria um **DirectShape por objeto**, guardando a malha triangulada *inteira*
   — não há geometria paramétrica reaproveitada, nem instâncias de família compartilhando
   uma definição. Cada tubo, cada eletroduto, cada perfil de barramento vira um sólido único.
2. Todo `IfcPropertySet` vira **parâmetro compartilhado**. É exatamente isso que os arquivos
   `.ifc.shared.txt` (63 / 26 / 38 KB) mostram: centenas de parâmetros criados no projeto.
   O de ARQ (63 KB) indica o modelo mais "carregado" de propriedades.
3. O RVT acumula overhead que o IFC não tem: histórico de elementos, tabela de tipos,
   vistas geradas, materiais duplicados por objeto.

### O formato/MVD do IFC impacta, e muito

| Variante | Efeito na conversão |
|---|---|
| **IFC4 Reference View** | Geometria já **tesselada** (malha). Pior caso: o Revit não tem como reconstruir sólido, tudo vira mesh pesada. |
| **IFC2x3 / IFC4 Design Transfer View** | Geometria **B-Rep / extrusões (SweptSolid)**. O Revit reconstrói sólidos limpos → RVT sensivelmente menor e mais rápido. |
| **IFC-SPF (.ifc texto)** vs **.ifcZIP** | Só muda o tamanho em disco do IFC, não o RVT resultante. |
| **Coordination View 2.0** | Bom equilíbrio para vínculo de coordenação. |

Regra prática: **peça o IFC 2x3 CV2.0 ou IFC4 DTV** aos projetistas. Um Reference View
tesselado pode dobrar de novo o peso do RVT convertido e derrubar a performance de seleção
e regeneração no Revit.

---

## 2. Recomendação de fluxo — como ganhar performance

O ponto central: **o RVT convertido não deveria ser o vínculo de trabalho.**

### 2.1 Não converta — vincule o IFC direto (quando o uso é coordenação)
`Insert > Link IFC` cria um RVT-sombra (`nome.ifc.RVT`) gerenciado pelo Revit, mas o modelo
de trabalho não carrega os DirectShapes na sessão do mesmo jeito que um RVT aberto e vinculado.
Para **conferência visual e checagem de interferência**, é o caminho mais leve.
Converta para RVT só quando precisar **editar, filtrar por parâmetro ou extrair quantitativo**.

### 2.2 Se converter, faça uma "limpeza" e congele
Depois do `Open IFC` → `Save As` RVT, execute uma rotina de purga e trate esse arquivo como
**derivado descartável** (é regerado a cada revisão do IFC, nunca editado):
- `Purge Unused` 3× seguidas (materiais, tipos, padrões de preenchimento órfãos);
- apagar **todas as vistas exceto uma 3D** e todas as folhas;
- apagar níveis/eixos duplicados vindos do IFC;
- desativar `Room Bounding` nos DirectShapes que não precisam;
- salvar com **`Compact`** marcado.
Em modelos como o ARQ de 122 MB, essa rotina costuma devolver de 25% a 40% do tamanho.

### 2.3 Regras de vínculo no modelo receptor
- Vincular sempre com **Origin to Origin** (ou Shared Coordinates), **nunca** movendo o vínculo à mão.
- Marcar o vínculo como **Pinned** logo após inserir.
- Trabalhar com os vínculos **Unloaded** e recarregar só quando necessário
  (`Manage Links > Unload`), ou usar **Worksets por vínculo**: 1 workset dedicado por
  disciplina vinculada, fechado por padrão. Isso é o que mais devolve performance.
- Usar **View Filters / Visibility por vínculo** em vez de deixar tudo visível nas vistas de trabalho.
- Em vistas 2D, evitar `Attachment: Overlay` de vínculos que não precisam aparecer.

### 2.4 ⚠️ Achado crítico: OneDrive
Nas duas capturas, **todos os arquivos exibem o ícone de status ❌ (erro de sincronização
do OneDrive)** e os `.ifc.log` estão associados ao Chrome. Dois problemas:
1. **Vínculo Revit em pasta sincronizada por nuvem é fonte recorrente de corrupção e de
   lentidão** — o cliente de sincronização tenta subir o arquivo enquanto o Revit o mantém aberto.
2. **Files On-Demand**: se o arquivo estiver "somente na nuvem", o Revit falha ao carregar
   o vínculo ou trava enquanto baixa 122 MB.

**Ação**: mover a pasta de vínculos para um **servidor/UNC local** (ou usar um CDE de verdade —
ACC / BIM 360 / SharePoint com `Desktop Connector`), e marcar a pasta como
**"Sempre manter neste dispositivo"** enquanto o OneDrive for a solução. Resolver os ❌ antes de
qualquer análise de performance — parte da lentidão percebida pode ser sincronização, não modelo.

---

## 3. Estrutura de pastas padrão (nomenclatura CDE — ISO 19650)

A ISO 19650 organiza a informação em **4 estados**. Sugestão aplicável já ao HB 3321:

```
HB3321-GonçalvesDias/
├── 00-WIP/                      # Work In Progress — só a equipe autora
│   ├── ARQ/  ELE/  HID/  EST/  CLI/
│   └── _SUPORT/                 # famílias, templates, dynamo, keynotes
├── 10-SHARED/                   # Compartilhado — verificado, para coordenação
│   ├── MODELS/
│   │   ├── NATIVE/              # .rvt nativos por disciplina
│   │   ├── IFC/                 # .ifc recebidos/emitidos  ← sua pasta atual
│   │   └── IFC-CONVERTED/       # .rvt derivados do IFC (descartáveis)
│   ├── DRAWINGS/                # PDF/DWG de referência  ← sua pasta "REFERÊNCIAS"
│   ├── COORDINATION/            # .nwd/.nwf, relatórios de clash, BCF
│   └── DATA/                    # planilhas, quantitativos, exports Dynamo
├── 20-PUBLISHED/                # Publicado — aprovado pelo cliente, por revisão
│   └── R00/ R01/ R02/ ...
└── 30-ARCHIVE/                  # Arquivado — congelado, somente leitura
    └── AAAA-MM-DD_marco/
```

Complementos:
- `_INCOMING/` (ou `40-RECEBIDOS/`) por remetente e data, para tudo que chega de terceiros
  **antes** de virar SHARED. Nada entra em `10-SHARED` sem checagem.
- Estados ISO 19650: **S** (shared), **A** (published/authorized), com o código de adequação
  (`S0 WIP`, `S1 para coordenação`, `S2 para informação`, `A1..An aprovado`).

### Nomenclatura de arquivo
O padrão em uso já é coerente e deve ser mantido:
`2001-EXE-ARQ-0001-MOD-R05` = `Projeto-Fase-Disciplina-Sequencial-Tipo-Revisão`.
Ajustes sugeridos:
- Padronizar a sigla elétrica: aparece **ELE** no arquivo e **ELET** na conversa. Escolher uma.
- **Nunca** usar data no meio do nome, como em `...-GER-R07(26-09-24_1...)`.
  A revisão (`R07`) já é o controle; a data cria ambiguidade e quebra scripts de leitura
  (Dynamo/Python que fazem `split("-")`). Mover a data para o metadado ou para o sufixo do
  pacote de emissão, não para o nome do modelo.
- `FOR` (barramento/formas?) deveria seguir a lista de disciplinas do escritório —
  se é barramento blindado, a sigla natural seria **ELE** com subcódigo, ou **BAR** se
  o escritório o trata como pacote próprio de fornecedor.

---

## 4. Posicionamento ARQ × ELE × BARRAMENTO

Só é possível confirmar abrindo os arquivos, mas o inventário permite apontar o risco e o método.

**Risco identificado**: modelos de origens diferentes (ARQ do escritório de arquitetura,
FOR de fornecedor de barramento) raramente compartilham a mesma origem. O IFC carrega
`IfcSite`/`IfcLocalPlacement` com coordenadas próprias — o fornecedor tipicamente entrega o
barramento **na origem interna dele (0,0,0)**, não nas coordenadas da obra.

**Protocolo a fixar no escritório:**
1. A **ARQ é a referência mestra de coordenadas**. Todo mundo usa a origem dela.
2. Exportar IFC sempre com **Shared Coordinates** ou **Project Base Point** — combinado e
   registrado no BEP, igual para todas as disciplinas.
3. Vincular sempre **Origin to Origin** e **Pin**. Se um vínculo só encaixa sendo movido à
   mão, o problema está na exportação — devolver ao emissor, não corrigir no receptor.
4. Verificação rápida: em uma vista 3D, checar se as lajes da ARQ, os eletrodutos da ELE e
   o trecho de barramento coincidem em cota (Z) e alinhamento de eixo. Divergência em Z é
   quase sempre nível de referência trocado na exportação.
5. `Coordination Review` (`Collaborate > Coordination Review`) para monitorar movimentação
   de vínculo entre revisões.

---

## 5. Pasta REFERÊNCIAS (PDF de plantas baixas)

Também não pôde ser aberta nesta sessão. Método de conferência contra ARQ (RVT e IFC):

1. **Revisão**: o PDF corresponde ao **R05** do ARQ? PDF de referência é a causa nº 1 de
   modelagem sobre informação vencida. Todo PDF em `10-SHARED/DRAWINGS/` deve carregar
   a mesma revisão do modelo que o originou, no nome do arquivo.
2. **Escala**: importar o PDF no Revit (`Insert > Image/PDF`), medir uma distância conhecida
   (vão de eixos, largura de porta) e comparar com o modelo. Diferença sistemática de ~2,5%
   é sinal de PDF impresso "ajustar à página".
3. **Cota Z / nível**: PDF é 2D — associar cada planta ao nível correto do RVT antes de usar.
4. **Divergência ARQ**: se o PDF mostra parede/shaft que o IFC não tem (ou vice-versa),
   o IFC provavelmente foi exportado de uma versão diferente. Comparar a data do IFC
   (18/05/2026) com a data de emissão do PDF.
5. **Regra**: o PDF serve como *conferência*, o modelo é a fonte de verdade. Não modelar
   elétrica sobre PDF quando existe RVT/IFC de arquitetura disponível.

---

## 6. Plano de ação resumido

| Prioridade | Ação | Ganho esperado |
|---|---|---|
| 1 | Resolver os ❌ do OneDrive / tirar vínculos de pasta sincronizada | elimina travamento e risco de corrupção |
| 2 | Solicitar IFC em **2x3 CV2.0 / IFC4 DTV** (não Reference View) | RVT convertido menor e com sólidos reais |
| 3 | Vincular IFC direto para coordenação; converter só quando precisar editar/extrair | evita carregar 122 MB de DirectShape |
| 4 | Rotina de purga + `Compact` nos RVT convertidos | −25% a −40% de tamanho |
| 5 | 1 workset por vínculo, fechado por padrão | maior ganho de performance em sessão |
| 6 | Adotar a estrutura CDE (00-WIP / 10-SHARED / 20-PUBLISHED / 30-ARCHIVE) | rastreabilidade de revisão |
| 7 | Remover data do nome de arquivo (`R07(26-09-24...)`) | scripts Dynamo estáveis |
| 8 | Fixar ARQ como origem mestra + Origin to Origin + Pin | fim do desalinhamento entre disciplinas |
