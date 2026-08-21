# Análise Técnica — Rotinas Dynamo, Documentos da Pasta e Modelo

Auditoria do conteúdo do repositório e do que é observável do modelo Revit a partir das
capturas de tela. Estruturada em: inventário → análise arquivo a arquivo → defeitos
encontrados (com severidade) → divergências entre as duas rotinas → plano de correção.

> **Escopo da análise do modelo:** não tenho acesso ao arquivo `.rvt` — ele não está no
> repositório (e o `.gitignore` sequer prevê `.rvt`, só backups). Tudo que digo sobre o
> modelo foi inferido de `1.png`, `2.png`, da captura da janela de Propriedades e dos
> nomes gravados dentro dos `.dyn`. Onde a inferência é incerta, está marcado.

---

## 1. Inventário da pasta

| Arquivo | Tipo | Situação |
|---|---|---|
| `Dynamo_ebpos_Cloude.dyn` | Grafo Dynamo, 8 nós | **Protótipo não funcional** — ver §2.1 |
| `MEGA Rotina_EDF_EBPOS.dyn` | Grafo Dynamo, 7 nós | **Funcional, com defeitos** — ver §2.2 |
| `1.png` | Captura do Dynamo | Fonte do catálogo real de famílias — §3.1 |
| `2.png` | Captura de vista do Revit | Fonte da geometria de referência — §3.2 |
| `README.md` | Doc | Desatualizado: cita `Dynamo_ebpos_Claude.dyn` (com "a"), arquivo real é `Cloude` |
| `.gitignore` | Config | Ignora `*.bak` e backups `.0001.rvt`, mas **não ignora `.rvt`/`.rfa`** |

---

## 2. Análise das rotinas

### 2.1 `Dynamo_ebpos_Cloude.dyn` — protótipo abandonado

**O grafo tem duas metades desconectadas:**

```
[Select Model Element] → [Element.Geometry] → [List.FirstItem] → ┬→ [Curve.Length]
                                                                 ├→ [Curve.StartPoint] ┐
                                                                 └→ [Curve.EndPoint]   ┴→ [Vector.ByTwoPoints]

[Python Script]  ← nó órfão, sem entrada e sem saída conectada
```

Constatações:

1. **O nó Python não está ligado a nada** e **não define `OUT`**. Ele contém exclusivamente
   o dicionário `MAPA_NIVEIS`. Executar o grafo não produz nenhum efeito no modelo.
2. A cadeia geométrica extrai comprimento e vetor de direção de **um único** elemento
   (`DSModelElementSelection`, singular) e termina em `Vector.ByTwoPoints` — o resultado
   não alimenta nada.
3. `Element.Geometry` → `List.FirstItem` retorna o primeiro **sólido** da geometria, não uma
   curva. Passar isso para `Curve.Length` / `Curve.StartPoint` provavelmente já falha. Para
   obter a curva de uma eletrocalha o caminho é `Location.Curve` (como a MEGA faz), não
   `Element.Geometry`.

**Valor real deste arquivo:** ele não é uma rotina, é a **especificação da prumada**. O
`MAPA_NIVEIS` é o único lugar do repositório onde a regra de projeto está escrita de forma
declarativa e completa (nível → peça → quadro de medição alimentado). Isso deve ser
preservado e promovido a fonte única de verdade (§5).

### 2.2 `MEGA Rotina_EDF_EBPOS.dyn` — rotina de produção

```
[Select Model Elements] ─────────────────────────────→ IN[0]
[Barramento-Reto:HBC-A-1000A] ──────────────────────→ IN[1]  fam_reto_alta
[Barramento-Derivação-1 Plugue:HBC-A-1000A] ────────→ IN[2]  fam_ed1_alta
[Barramento-Redução-400A-2500A:HBC-A-1000A-0800A] ──→ IN[3]  fam_redutor
[Barramento-Reto:HBC-A-0800A] ──────────────────────→ IN[4]  fam_reto_baixa
[Barramento-Derivação-1 Plugue:HBC-A-0800A] ────────→ IN[5]  fam_ed1_baixa
```

**O que ela faz:** varre eletrocalhas selecionadas, lê o nível de cada uma, escolhe uma das
5 famílias por regra de nome de nível, insere a peça no ponto médio da curva, escreve o
comprimento no parâmetro `Comprimento`, rotaciona em torno de Z e **apaga a eletrocalha
original**.

**Acertos:** função antiduplicidade recursiva; ativação preventiva das famílias
(`IsActive`/`Activate()`); uso de `curva.Length` em pés — coerente com o que
`Parameter.Set(double)` espera, sem conversão indevida; `try`/`traceback` global; relatório
textual de saída.

---

## 3. O que as capturas revelam do modelo

### 3.1 `1.png` — ambiente e catálogo de famílias

- **Revit 2025.4**, Dynamo 3.x, pacotes **BIMCoder Nodes** e **GeniusLoci** instalados.
- Grafo `Estudo_1.dyn` (não versionado neste repositório).
- **Catálogo real de barramentos no modelo** — este é o achado mais importante:

| Família | Tipos visíveis |
|---|---|
| `Barramento-Reto` | `HBC-A-0400A`, `-0630A`, `-0800A`, `-1000A`, `-1250A`, `-1600A` |
| `Barramento-Redução-400A-2500A` | `HBC-A-1600A-1250A`, `-2000A-1250A`, `-2000A-1600A`, `-2500A-1600A`, `-2500A-2000A` (lista rolada; pares menores existem acima) |
| `Barramento-Derivação-1 Plugue` | `HBC-A-0800A`, `HBC-A-1000A` (confirmados pelos nós da MEGA) |

Duas consequências diretas:

1. **A redução é uma família única de faixa** (`Barramento-Redução-400A-2500A`) com o par
   de correntes no **nome do tipo**, não uma família por par. O comentário do
   `Dynamo_ebpos_Cloude.dyn` — `"Barramento-Redução-1250A-1000A"` — **não corresponde a
   nenhum nome real** no modelo.
2. **A corrente já está codificada no nome do tipo** (`HBC-A-1000A`). Filtros, tabelas e
   verificações podem ler o **Nome do tipo** direto, sem depender de parâmetro novo.

### 3.2 `2.png` — a geometria de referência

A imagem mostra o padrão de modelagem em uso: um **trecho vertical fino em azul** (traçado
de eletrocalha/prumada) descendo de uma **curva/cotovelo** superior até outra **curva
inferior**, que vira para um **trecho horizontal amarelo** (elemento selecionado, largura
real). Ou seja: a prumada é modelada primeiro como **eletrocalha nativa** servindo de
traçado, e depois substituída pelas peças de barramento — exatamente o que a MEGA faz.

Isso expõe dois pontos que as rotinas não tratam:

- **Os cotovelos (curvas) não são substituídos.** A MEGA só processa elementos com
  `Location.Curve`; conexões de eletrocalha (fittings) não têm e são ignoradas pelo `continue`.
  Como os trechos retos adjacentes **são apagados**, o modelo fica com cotovelos de
  eletrocalha nativa órfãos, sem par de barramento — visível em §3.2 justamente nos dois
  pontos onde a prumada muda de direção.
- **O trecho é vertical.** Isso quebra a rotação da MEGA — ver Defeito **A1**.

### 3.3 A janela de Propriedades

Vista `Planta Baixa / Térreo`, 1:50, Nível de detalhe Alto, **Disciplina = Coordenação**,
sem template de vista aplicado, sem caixa de escopo, e com
`Estilo de exibição de análise padrão = CONEXÕES COM L1 - L2 INVERTIDO` ativo. Tratado em
detalhe no §8 de `TEMPLATE_BARRAMENTO_BLINDADO.md`.

---

## 4. Defeitos encontrados na MEGA (por severidade)

### A — Impedem o resultado correto

**A1 · Rotação não funciona em trecho vertical** — *este é o defeito mais grave para uma prumada.*
```python
direcao = (ponto_final - ponto_inicial).Normalize()
angulo  = XYZ.BasisX.AngleOnPlaneTo(direcao, XYZ.BasisZ)
```
Para um trecho vertical `direcao ≈ (0,0,1)`. A projeção de um vetor vertical no plano XY é
degenerada: o ângulo retornado é indefinido/zero e a peça é inserida **deitada na
horizontal**. A rotina só orienta corretamente trechos horizontais — e o objeto do projeto
é justamente a prumada vertical.
*Correção:* detectar verticalidade (`abs(direcao.Z) > 0.99`) e, nesse caso, rotacionar 90°
em torno de um eixo horizontal perpendicular à peça antes de qualquer giro em Z.

**A2 · Redutor recebe o comprimento do trecho inteiro**
No nível do 5º pavimento a rotina escolhe o redutor e depois faz
`param_tamanho.Set(tamanho_exato)` com o comprimento da eletrocalha do pé-direito inteiro.
Um redutor tem comprimento fixo de catálogo — esticá-lo até ~3 m produz uma peça
inexistente e um quantitativo errado. Além disso, o pavimento fica **sem trecho reto**: o
redutor ocupa tudo.
*Correção:* o trecho do 5º precisa ser dividido em `reto + redutor + reto`, ou o redutor
inserido como peça adicional em posição definida, mantendo o parâmetro de comprimento
intocado.

**A3 · Derivações do `MAPA_NIVEIS` não são inseridas**
O `MAPA_NIVEIS` prevê, no 5º pavimento, `peca_extra: "Barramento-Derivação-1 Plugue"`
**junto** com a redução. A MEGA insere **uma peça por eletrocalha** — nunca duas. O plugue
de derivação do duplex simplesmente não é modelado.

**A4 · Cotovelos ficam órfãos** — ver §3.2. Nenhuma família `Barramento-Curva` está mapeada,
e o catálogo do §3.1 não mostra uma. É preciso confirmar se ela existe na biblioteca.

### B — Corrompem o modelo em silêncio

**B1 · Nós `Family Types` guardam índice, não só nome**
```json
{"SelectedIndex": 140, "SelectedString": "Barramento-Reto:HBC-A-1000A"}
```
Se um tipo for carregado, renomeado ou purgado, os índices deslocam e o nó pode passar a
apontar para **outra família sem avisar** — a rotina roda "com sucesso" e modela a peça
errada. Sintoma clássico: a rotina funcionava e "do nada" começou a inserir peça trocada.
*Correção:* trocar os 5 nós por busca por nome dentro do Python (`FilteredElementCollector`
+ comparação de `FamilyName` e `Name`), falhando explicitamente se não achar.

**B2 · Casamento de nível por substring**
```python
if "5º" in nome_nivel: ...
elif "TÉRREO" in nome_nivel or "3º" in nome_nivel or "7º" in nome_nivel ...
```
`"5º"` casa com `05NA-...`, mas casaria também com `15º` e `25º`; `"3º"` casa com
`3º PAVIMENTO` e com `13º`/`23º`. Em um edifício mais alto a regra colapsa.
*Correção:* casar pelo **nome completo do nível**, usando as chaves do `MAPA_NIVEIS` como
dicionário — que é exatamente para isso que ele existe.

**B3 · `LookupParameter("Comprimento")` sem verificação de escrita**
Se a família não tiver um parâmetro de instância `Comprimento`, o `LookupParameter` pode
retornar o parâmetro **nativo somente-leitura** e o `Set()` lança exceção — que sobe para o
`try` externo e **aborta o restante da prumada**. Além disso o nome é localizado: o mesmo
grafo em Revit em inglês não encontra `Comprimento`.
*Correção:* `if p and not p.IsReadOnly and p.StorageType == StorageType.Double`.

**B4 · Falha em um elemento aborta todos**
Não há `try` por elemento. Com exceção no elemento nº 7 de 20, os 6 primeiros já foram
inseridos e as 6 eletrocalhas já foram apagadas; `TransactionTaskDone()` nunca é chamado e
o estado final fica indefinido.
*Correção:* `try/except` dentro do laço, acumulando falhas no relatório, e transação única
fechada no `finally`.

**B5 · `doc.Delete(elem.Id)` destrói o traçado de origem**
A eletrocalha-guia é apagada na mesma passada. Se a inserção tiver saído errada (e por A1
ela sai, em prumada), **não há como reexecutar**: o traçado não existe mais. Apagar
conexões de eletrocalha também pode arrastar fittings vizinhos.
*Correção:* não apagar na mesma execução. Marcar (`Comentários = "SUBSTITUIDO"`) ou mover
para um workset `ZZ-GUIA-ELIMINAR`, e apagar em rotina separada após conferência.

### C — Manutenção

**C1 · Código morto:** `if is_baixa or "7º" in nome_nivel or "ÁTICO" in nome_nivel` —
`ÁTICO` já está em `andares_baixa`, então `is_baixa` já é `True`; o resto da condição nunca
é avaliado.
**C2 · `"7º"` não existe** na lista de níveis real (o edifício vai até `06NA-ÁTICO-ELT`) —
regra escrita para um prédio que não é este.
**C3 · `doc.Regenerate()` dentro do laço** a cada elemento: custo alto e desnecessário na
maioria dos casos.
**C4 · `Id.IntegerValue`** está obsoleto no Revit 2024+ (`Id.Value` é o substituto); ainda
funciona no 2025, mas vai quebrar.
**C5 · README** aponta nome de arquivo errado (`Claude` vs `Cloude`) e descreve o
`Dynamo_ebpos_Cloude.dyn` como "rotina de inserção" quando ele não insere nada.

---

## 5. Divergência entre as duas rotinas — a raiz do problema

As duas rotinas descrevem **projetos elétricos diferentes**:

| Item | `Dynamo_ebpos_Cloude.dyn` | `MEGA Rotina_EDF_EBPOS.dyn` |
|---|---|---|
| Corrente da prumada | 1250 A → 1000 A | 1000 A → 800 A |
| Nome da redução | `Barramento-Redução-1250A-1000A` (inexistente) | `Barramento-Redução-400A-2500A:HBC-A-1000A-0800A` (real) |
| Níveis com derivação | Térreo, 3º, 5º, Ático | Térreo, 3º, **7º**, Ático |
| Quadro alimentado (CM) | mapeado nos 4 níveis | **ignorado** |
| Nível 2º (TIPO) | reto | reto (via `else`) |
| Peça extra no 5º | derivação + redução | só redução |
| Chave de decisão | nome completo do nível | substring do nome |

Enquanto existirem duas descrições da mesma prumada, qualquer correção em uma delas
reintroduz o erro pela outra. **A `MAPA_NIVEIS` deve virar a única fonte de verdade** e a
MEGA deve consumi-la, em vez de reimplementar a regra em `if/elif`.

Esqueleto do que resolve B2, C1, C2 e A3 de uma vez:

```python
# MAPA_NIVEIS passa a carregar a corrente e as peças extras
MAPA_NIVEIS = {
    "00NA-TÉRREO-ELT": {
        "familia": "Barramento-Derivação-1 Plugue",
        "tipo":    "HBC-A-1000A",
        "cm":      "CM_TERREO",
        "extras":  [],
    },
    "04NA-5º PAVIMENTO - DUPLEX INFERIOR-ELT": {
        "familia": "Barramento-Redução-400A-2500A",
        "tipo":    "HBC-A-1000A-0800A",
        "cm":      "CM_DUPLEX",
        "extras":  [("Barramento-Derivação-1 Plugue", "HBC-A-0800A")],
    },
    # ...
}

regra = MAPA_NIVEIS.get(nivel.Name)      # nome COMPLETO, sem substring
if regra is None:
    falhas.append("Nível fora do mapa: " + nivel.Name)
    continue
```

E a resolução de tipo por nome, que elimina B1:

```python
def achar_tipo(doc, nome_familia, nome_tipo):
    for s in FilteredElementCollector(doc).OfClass(FamilySymbol):
        if s.Family.Name == nome_familia and s.Name == nome_tipo:
            return s
    raise Exception("Tipo não encontrado: %s : %s" % (nome_familia, nome_tipo))
```

---

## 6. Plano de correção sugerido, em ordem

| # | Ação | Resolve |
|---|---|---|
| 1 | Unificar a regra no `MAPA_NIVEIS` com família + tipo + CM + extras | §5, A3, B2, C1, C2 |
| 2 | Resolver famílias por nome no Python; remover os 5 nós `Family Types` | B1 |
| 3 | Tratar trecho vertical na rotação | **A1** |
| 4 | Não apagar a eletrocalha-guia na mesma execução; marcar e apagar depois | B5 |
| 5 | `try/except` por elemento + relatório de falhas | B4 |
| 6 | Guardar o `Set()` do parâmetro (`IsReadOnly`, `StorageType`) | B3 |
| 7 | Decidir o tratamento do redutor (não esticar) e dos cotovelos | A2, A4 |
| 8 | Gravar os parâmetros `ELT_*` na inserção | integra com o template |
| 9 | Atualizar README e `.gitignore` (`*.rvt`, `*.rfa`, `backup/`) | C5 |

O item 8 é o que fecha o ciclo com `TEMPLATE_BARRAMENTO_BLINDADO.md`: com os parâmetros
gravados na inserção, o filtro magenta `ELT-BUSWAY-SemParametro` e a tabela
`TB-BUSWAY-Derivacoes` passam a conferir automaticamente o resultado de cada execução
contra o `MAPA_NIVEIS`.

---

## 7. Correções aplicadas ao roteiro de template

`TEMPLATE_BARRAMENTO_BLINDADO.md` foi escrito antes desta análise, a partir dos comentários
do `Dynamo_ebpos_Cloude.dyn`. Três pontos foram corrigidos com os dados reais do modelo:

- Correntes da prumada: **1000 A → 800 A** (não 1250 → 1000).
- Nome da família de redução: **`Barramento-Redução-400A-2500A`**, tipo `HBC-A-1000A-0800A`.
- Filtros de corrente passam a ler o **Nome do tipo** (`HBC-A-1000A`), que já existe, em vez
  de depender do parâmetro novo `ELT_Corrente_A` — que continua útil para tabelas e ordenação.
