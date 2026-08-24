# Análise de vínculos — HB 3321 / Obra Gonçalves Dias

**Projeto:** 2001 — Fase EXE
**Escopo:** vínculos ARQ, ELE e BARRAMENTO (FOR-0020-GER) em IFC e RVT
**Base de dados:** capturas de tela das pastas `VÍNCULOS\IFC's` e da pasta de vínculos RVT

> Os números abaixo foram lidos das capturas de tela. Para o inventário completo
> (hash, cabeçalho do IFC, geometria, PDFs), rode `scripts\Auditoria-Vinculos.ps1`
> na máquina onde os arquivos estão.

---

## 1. O que o Explorer está escondendo

O Windows oculta a extensão de tipos registrados. É por isso que a mesma pasta mostra
dois arquivos com nomes aparentemente iguais e ícones diferentes:

| O que aparece na tela | O que o arquivo é de fato | Origem |
|---|---|---|
| `2001-EXE-ARQ-0001-MOD-R05` — *IFC File* | `...R05.ifc` | recebido da arquitetura |
| `2001-EXE-ARQ-0001-MOD-R05.ifc` — *Autodesk Revit Project* | `...R05.ifc.rvt` | **gerado pelo Revit** ao abrir/vincular o IFC |
| `2001-EXE-ARQ-0001-MOD-R05.ifc.log` | log da importação | gerado pelo Revit |
| `2001-EXE-ARQ-0001-MOD-R05.ifc.shared-parameters.txt` | parâmetros compartilhados | gerado pelo Revit |
| `ELET_GUIA` — *Autodesk Revit Project* | `ELET_GUIA.rvt` | cópia manual |

**Ação imediata:** Explorer → Exibir → Mostrar → *Extensões de nomes de arquivos*.
Sem isso a equipe não distingue o IFC do RVT gerado a partir dele.

---

## 2. Inventário reconstruído

### 2.1 Pasta `VÍNCULOS\IFC's` — origem + subprodutos da importação

| Modelo | IFC | RVT gerado (`.ifc.rvt`) | Δ | shared-parameters |
|---|---:|---:|---:|---:|
| ARQ-0001-MOD-R05 | 87,03 MB | 122,08 MB | **+40,3 %** | 63 KB |
| ELE-0001-MOD-R04 | 56,53 MB | 90,12 MB | **+59,4 %** | 26 KB |
| FOR-0020-GER-R07 | 10,79 MB | 22,21 MB | **+105,8 %** | 38 KB |
| **Total** | **154,4 MB** | **234,4 MB** | **+51,9 %** | 127 KB |

### 2.2 Pasta de vínculos RVT — o que realmente é carregado no Revit

| Arquivo | Tamanho | Modificado | Diagnóstico |
|---|---:|---|---|
| `2001-EXE-ARQ-0001-MOD-R05.ifc.rvt` | 122,09 MB | 22/05 12:43 | mesmo da pasta IFC's, +16 KB |
| `2001-EXE-ELE-0001-MOD-R04.ifc.rvt` | 90,12 MB | 19/05 09:04 | mesmo da pasta IFC's, +4 KB |
| `2001-EXE-FOR-0020-GER-R07(...).ifc.rvt` | 22,22 MB | 22/05 14:20 | mesmo da pasta IFC's, +12 KB |
| `ELET_GUIA.rvt` | 90,12 MB | 19/05 13:02 | **tamanho idêntico ao ELE — duplicata** |
| **Carga total de vínculos** | **324,6 MB** | | |

A diferença de 4 a 16 KB em relação à pasta `IFC's` é a assinatura de um
**abrir-e-salvar no Revit** (atualização de preview e cabeçalho), não de uma nova
conversão. São os mesmos arquivos — respondendo diretamente à sua suspeita.

---

## 3. Achados

### 3.1 CRÍTICO — `ELET_GUIA.rvt` é duplicata do modelo elétrico

90,12 MB, byte a byte o mesmo tamanho do `2001-EXE-ELE-0001-MOD-R04.ifc.rvt`
que está na mesma pasta. Se os dois estiverem vinculados ao mesmo modelo:

- RAM e geometria do elétrico **dobradas**;
- interferências falsas em cada eletroduto/eletrocalha (cada peça colide consigo mesma);
- quantitativos dobrados;
- 90 MB de carga sem nenhuma informação nova.

Confirme antes de excluir:

```powershell
Get-FileHash "...\2001-EXE-ELE-0001-MOD-R04.ifc.rvt" -Algorithm SHA256
Get-FileHash "...\ELET_GUIA.rvt" -Algorithm SHA256
```

Hash igual = cópia literal, pode apagar. Hash diferente com o mesmo tamanho =
foi salvo como novo a partir do mesmo original, e alguém pode ter mexido nele —
aí compare a contagem de elementos nos dois antes de decidir.

**Substituto correto:** um "guia" de posicionamento não deve ser uma cópia de 90 MB
do modelo. Deve ser um RVT de poucos MB contendo apenas eixos, níveis, ponto-base e
ponto topográfico, com coordenadas compartilhadas publicadas. Ver seção 6.

### 3.2 CRÍTICO — projeto dentro do OneDrive

Caminho atual: `C:\Users\RODRIGO\OneDrive\Desktop\...`

Revit e pasta sincronizada não convivem. Durante a sessão o Revit mantém o `.rvt`
travado e grava `.0001.rvt`, `.slog` e journals; o OneDrive tenta subir cada versão,
gera conflito de bloqueio, cria arquivos `-Cópia em conflito` e é causa recorrente
de `.rvt` corrompido. Um modelo de 122 MB re-sincronizado a cada salvamento também
consome banda e trava a estação.

**Correto:** trabalhar em disco local (`C:\BIM\HB3321\`) ou em ACC/Revit Server.
Sincronizado (OneDrive/SharePoint) apenas para **troca e publicação**, nunca para
o arquivo aberto no Revit.

O ícone ❌ na coluna *Status* de todos os arquivos da pasta `IFC's` na segunda captura
indica exatamente isso: **falha de sincronização** — nenhum desses arquivos está
protegido na nuvem hoje.

### 3.3 ALTO — RVT gerado mais antigo que o IFC ao lado

Na pasta `IFC's`, todos os três `.ifc.rvt` são de 18/05 entre 11h38 e 11h43,
enquanto os três `.ifc` são de 18/05 entre 13h17 e 13h18 — **1h35 mais novos**.
Ou seja: os IFCs foram substituídos depois que a conversão foi feita.

As cópias na pasta de vínculos têm data posterior (19 e 22/05), mas isso não prova
que carregam o IFC novo: abrir e salvar no Revit atualiza a data sem reimportar nada.
Verifique pelo `.log` (`2001-EXE-ARQ-0001-MOD-R05.ifc.log`, alterado em 19/05 09:07)
ou simplesmente reconverta e compare.

**Regra de fluxo:** o `.ifc.rvt` é descartável e será **sobrescrito sem aviso** na
próxima importação do mesmo IFC. Nunca vincule direto dele nem o edite.

### 3.4 MÉDIO — nomenclatura quebrada em dois pontos

O padrão do escritório está bom: `2001-EXE-ARQ-0001-MOD-R05`
(projeto-fase-disciplina-sequencial-tipo-revisão). Dois desvios:

| Arquivo | Problema | Correção |
|---|---|---|
| `...GER-R07(26-09-24_10h17min29s)` | carimbo de data da exportação do fornecedor dentro do nome | renomear na entrada: `2001-EXE-ELE-0020-BARR-R07.rvt` |
| `ELET_GUIA` | sem projeto, fase, disciplina ou revisão | `2001-EXE-ELE-0000-COORD-R00.rvt` |
| todos os `.ifc.rvt` | extensão dupla, some da vista com extensões ocultas | renomear ao promover para vínculo oficial |

Sobre o código `FOR`: fornecedor é **origem**, não disciplina. O barramento é elétrico —
deve entrar como `ELE`, com a procedência registrada na pasta (`50_INCOMING`) e no
BEP, não no código da disciplina. Senão o barramento fica fora de qualquer filtro,
tabela ou verificação por disciplina.

### 3.5 MÉDIO — parâmetros compartilhados inflando a conversão

`shared-parameters.txt` de 63 KB (ARQ) e 38 KB (barramento) significam **centenas de
parâmetros** criados na importação — cada property set do IFC vira parâmetro de projeto
no RVT gerado. É um dos maiores responsáveis pelo salto de +40 a +106 % no tamanho e
pela lentidão de abertura.

Chama atenção o barramento: 10,79 MB de IFC gerando 38 KB de parâmetros — proporcionalmente
o triplo do ARQ. Exportação de fornecedor costuma vir com "exportar todas as propriedades"
ligado, despejando dados de fabricação que não servem à coordenação.

### 3.6 MÉDIO — caminho hostil a automação

`VERIFICAÇÃO DE MODELOS\HB 3321 - OBRA Gonçaves Dias\VÍNCULOS\IFC's`

- **apóstrofo** em `IFC's` — quebra scripts Dynamo/Python, linha de comando e upload ACC;
- **acentos e cedilha** (`VERIFICAÇÃO`, `VÍNCULOS`, `Gonçaves`) — quebra bibliotecas que não tratam UTF-8;
- **espaços + caminho longo** — risco de estourar os 260 caracteres do Windows;
- `Gonçaves` parece erro de digitação de `Gonçalves`.

---

## 4. IFC → RVT engorda ou emagrece?

**Engorda, sempre.** Nos seus três casos: +40,3 %, +59,4 % e +105,8 %.

Não é anomalia, é como os dois formatos funcionam:

| | IFC (SPF/STEP) | RVT |
|---|---|---|
| Formato | texto puro, altamente redundante | armazenamento composto binário |
| Geometria | definição compacta (extrusão + perfil) | sólido resolvido, parâmetros e cache de exibição por elemento |
| Repetição | `IfcMappedItem` referencia uma vez | cada instância vira elemento com registro próprio |
| Propriedades | property sets em texto | parâmetros compartilhados + definições de família |
| Extra | — | preview, estado de vistas, tipos, materiais, DirectShape |

Na importação o Revit ainda **cria uma família para cada tipo de objeto IFC**. Um IFC
de 10 MB com 4.000 peças de barramento vira um RVT com milhares de definições de
família — daí o +106 % do arquivo do fornecedor, justamente o menor dos três.

---

## 5. O formato do IFC importa? Muito.

O que dita o peso do RVT resultante não é o tamanho do IFC, é **como a geometria foi
serializada**:

| Formato / MVD | Geometria | Efeito no Revit |
|---|---|---|
| **IFC 2x3 Coordination View 2.0** | `IfcExtrudedAreaSolid` + `IfcBooleanClippingResult` | **melhor caso** — sólidos leves, importação rápida |
| **IFC4 Design Transfer View** | CSG / Advanced B-rep | bom, mas suporte parcial do importador |
| **IFC4 Reference View** | `IfcTriangulatedFaceSet` (malha, por definição do MVD) | **pior caso** — tudo vira malha, arquivo explode, navegação trava |
| **IFC com Faceted B-rep** | `IfcFacetedBrep` | idem: milhares de faces por peça |
| **ifcXML** | XML | 3–5× maior, sem ganho |
| **ifcZIP** | comprimido | menor para transferir, mesmo RVT no final |

A taxa de inflação denuncia o formato: **+40 % (ARQ)** é assinatura de sólidos
paramétricos, provavelmente export nativo Revit→IFC. **+106 % (barramento)** é
assinatura de malha. Rode `-Deep` no script para confirmar — ele conta
`IFCEXTRUDEDAREASOLID` contra `IFCTRIANGULATEDFACESET`/`IFCFACETEDBREP` e devolve
o percentual de malha.

### Especificação para pedir a quem exporta

```
Formato ............... IFC 2x3 Coordination View 2.0
Vista ................. 3D dedicada de coordenação (não a vista {3D})
Exportar somente elementos visíveis na vista .......... LIGADO
Exportar property sets comuns IFC .................... LIGADO
Exportar property sets do Revit / todas propriedades .. DESLIGADO
Exportar quantidades base ............................. DESLIGADO (salvo QTO acordado)
Exportar elementos 2D de vista em planta .............. DESLIGADO
Exportar caixa delimitadora ........................... DESLIGADO
Dividir paredes e pilares por nível ................... LIGADO (ARQ/EST)
Nível de detalhe da tesselagem ........................ BAIXO
Fase .................................................. a fase do projeto
```

Só isso costuma cortar 30–50 % do IFC antes mesmo da conversão.

### Impacto no fluxo de modelagem

O RVT vindo de IFC entrega `DirectShape`/`IfcElement`, não famílias nativas:

- não hospeda nada (não dá para criar abertura, tag ou luminária sobre ele);
- categorias genéricas — filtros e tabelas por categoria não funcionam como no nativo;
- sem níveis e ambientes associados, salvo mapeamento explícito;
- editar é possível, mas qualquer edição some na próxima reconversão.

**Portanto:** RVT vindo de IFC serve como **referência de coordenação** — nunca como
base para dependências de modelagem. Onde você precisa hospedar ou tagear, exija o
RVT nativo da disciplina.

---

## 6. Posicionamento — ARQ, ELET e BARRAMENTO

A existência de um `ELET_GUIA` indica posicionamento resolvido por cópia manual em vez
de coordenadas compartilhadas. Isso não sobrevive à próxima revisão: quando chegar o
ARQ R06, o guia continua na posição do R05 e ninguém percebe.

### Hierarquia correta

```
ARQ R05  ..............  MESTRE geométrico
   │                     define ponto-base e ponto topográfico
   │                     publica coordenadas compartilhadas
   ├─► ELE R04 ........  Adquirir Coordenadas a partir do ARQ
   │                     vincula ARQ como Sobreposição (Overlay)
   └─► BARRAMENTO R07 .  posicionado UMA vez em RVT container
                         herda as coordenadas do ARQ
```

### O container de fornecedor (substitui o ELET_GUIA)

Modelo de fornecedor chega em 0,0,0 com orientação própria. Não posicione o IFC dentro
de cada modelo de disciplina — a cada revisão alguém reposiciona e as versões divergem.

1. Novo projeto a partir do template do escritório: `2001-EXE-ELE-0020-BARR-R07.rvt`
2. Vincular o ARQ R05 por coordenadas compartilhadas
3. Vincular/importar o IFC do barramento e posicionar **uma vez**
4. Fixar o vínculo (Pin) e publicar as coordenadas
5. Descarregar o ARQ do container
6. Todas as disciplinas vinculam **o container**, por coordenadas compartilhadas

Na revisão seguinte só o IFC interno é trocado. Ninguém reposiciona nada.

### Regras de vínculo

| Item | Configuração | Por quê |
|---|---|---|
| Tipo de referência | **Sobreposição (Overlay)** | Anexo (Attach) propaga vínculos aninhados e multiplica a carga |
| Posicionamento | **Por Coordenadas Compartilhadas** | Origem-a-Origem só funciona se todos exportaram da mesma origem |
| Workset | **um por vínculo**, fechado por padrão | maior ganho de performance disponível |
| Distância da origem interna | **< 1 km** | além disso o Revit perde precisão e a geometria fica instável |
| Fixação | **Pin em todo vínculo** | impede mover por acidente |

---

## 7. PDFs de referência × arquitetura

Não consigo abrir os PDFs daqui. O protocolo de verificação, na ordem:

1. **Revisão** — a planta PDF tem que ser do mesmo `Rxx` do modelo. O ARQ está em
   **R05**: PDF em R04 é referência superada e produz retrabalho garantido. O script
   compara automaticamente a revisão do nome do PDF com a do modelo da disciplina.
2. **Data de emissão** — carimbo do PDF contra a data do RVT/IFC.
3. **Eixos** — imprima uma planta do modelo na mesma escala e confira o espaçamento
   entre eixos. Divergência aqui invalida tudo que vier depois.
4. **Níveis** — cota de piso acabado no carimbo × elevação do nível no modelo.
5. **Escala** — PDF de planta baixa de arquitetura precisa da escala declarada;
   sem ela não serve para conferência dimensional.
6. **Origem do PDF** — plotado do modelo ou vindo de um CAD legado? Se veio de CAD,
   ele **não** representa o RVT e não pode ser usado como referência de coordenação.

**Regra:** PDF é conferência visual e documental. Não é fonte geométrica. Divergência
entre PDF e modelo resolve-se sempre a favor do modelo — e vira RFI para a arquitetura.

---

## 8. Plano de ação

### Agora (ganho imediato, custo zero)

| # | Ação | Ganho |
|---|---|---|
| 1 | Ligar extensões de arquivo no Explorer | fim da confusão IFC × RVT |
| 2 | Conferir o hash do `ELET_GUIA` e eliminá-lo se for cópia | −90 MB, fim das interferências falsas |
| 3 | Tirar o projeto do OneDrive para disco local | fim de travamento, conflito e risco de corrupção |
| 4 | Um workset por vínculo, fechado por padrão | maior ganho isolado de RAM |
| 5 | Sobreposição + Pin em todos os vínculos | evita carga duplicada e deslocamento acidental |

### Nesta semana

| # | Ação | Ganho |
|---|---|---|
| 6 | Reconverter os 3 IFCs (os RVTs atuais podem estar defasados) | vínculos coerentes com a revisão |
| 7 | Purgar Não Utilizados + Auditar em cada RVT convertido | 15–30 % do tamanho |
| 8 | Renomear tirando o `.ifc` e o carimbo de data | rastreabilidade |
| 9 | Criar o container do barramento e aposentar o ELET_GUIA | posicionamento estável entre revisões |
| 10 | Enviar a especificação de export IFC (seção 5) às disciplinas | 30–50 % no próximo ciclo |

### Estruturante

| # | Ação | Ganho |
|---|---|---|
| 11 | Implantar a estrutura de pastas CDE (`docs/PADRAO_PASTAS_CDE.md`) | rastreabilidade e fim do vínculo em pasta errada |
| 12 | Coordenadas compartilhadas publicadas pelo ARQ | posicionamento resolvido de vez |
| 13 | NWC/NWD para revisão de interferência | tira 300 MB de vínculo do Revit de autoria |
| 14 | Rodar a auditoria a cada recebimento de revisão | problema detectado na entrada, não na obra |

---

## 9. Como rodar a auditoria

```powershell
# diagnóstico rápido
.\scripts\Auditoria-Vinculos.ps1 -Raiz "C:\Users\RODRIGO\OneDrive\Desktop\Rotinas_DYNAMO_CLAUDE\VERIFICAÇÃO DE MODELOS\HB 3321 - OBRA Gonçaves Dias"

# completo: abre os IFCs, classifica esquema e geometria, exporta CSV
.\scripts\Auditoria-Vinculos.ps1 -Raiz "C:\...\HB 3321 - OBRA Gonçaves Dias" -Deep -CsvOut "C:\Temp\auditoria_HB3321.csv"
```

Se der erro de política de execução:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Auditoria-Vinculos.ps1 -Raiz "C:\..."
```

O script é somente leitura — não move, renomeia nem apaga nada.
