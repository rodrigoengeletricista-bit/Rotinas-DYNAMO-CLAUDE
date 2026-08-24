<#
.SINOPSE
    Auditoria de vinculos (IFC / RVT / PDF) de um projeto BIM.

.DESCRICAO
    Varre a pasta do projeto e produz um diagnostico de performance e
    conformidade dos arquivos de vinculo:

      1. Inventario por extensao real (revela .ifc.rvt escondido pelo Explorer)
      2. Pareamento IFC -> RVT gerado, com taxa de inflacao (%)
      3. Conversoes desatualizadas (IFC mais novo que o .ifc.rvt)
      4. Arquivos duplicados por hash SHA256 (ex.: copias renomeadas)
      5. Conformidade de nomenclatura (padrao PROJ-FASE-DISC-SEQ-TIPO-Rxx)
      6. Cruzamento de revisao PDF x modelo, por disciplina
      7. Higiene de caminho (OneDrive, acentos, apostrofos, MAX_PATH)
      8. Peso morto (backups .0001.rvt, .log, .shared-parameters.txt)
      9. -Deep: le o cabecalho e a representacao geometrica de cada IFC
         (IFC2X3 x IFC4, MVD, exportador, solido x malha)

.EXEMPLO
    .\Auditoria-Vinculos.ps1 -Raiz "C:\...\HB 3321 - OBRA Goncaves Dias"

.EXEMPLO
    .\Auditoria-Vinculos.ps1 -Raiz "D:\BIM\HB3321" -Deep -CsvOut "D:\BIM\auditoria.csv"

.NOTAS
    Compativel com Windows PowerShell 5.1 (padrao do Windows) e PowerShell 7+.
    Somente leitura: o script nao move, renomeia nem apaga nada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Raiz,

    # Le o interior de cada .ifc para classificar esquema e geometria.
    # Custa ~30-60 s por arquivo de 90 MB.
    [switch] $Deep,

    # Caminho opcional para exportar o inventario completo em CSV.
    [string] $CsvOut,

    # Limite de caminho considerado arriscado (MAX_PATH classico = 260).
    [int] $LimiteCaminho = 220
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Utilitarios
# --------------------------------------------------------------------------

function Write-Secao {
    param([string] $Titulo)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
    Write-Host "  $Titulo" -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
}

function Write-Achado {
    param(
        [ValidateSet('CRITICO', 'ATENCAO', 'OK', 'INFO')]
        [string] $Nivel,
        [string] $Mensagem
    )
    $cor = switch ($Nivel) {
        'CRITICO' { 'Red' }
        'ATENCAO' { 'Yellow' }
        'OK'      { 'Green' }
        default   { 'Gray' }
    }
    Write-Host ("  [{0,-7}] {1}" -f $Nivel, $Mensagem) -ForegroundColor $cor
}

function ConvertTo-MB {
    param([long] $Bytes)
    return [math]::Round($Bytes / 1MB, 2)
}

# Nome sem NENHUMA extensao conhecida de vinculo, para parear IFC com RVT.
# "X.ifc.rvt" -> "X" ; "X.ifc" -> "X" ; "X.rvt" -> "X"
function Get-ChaveVinculo {
    param([string] $Nome)
    $n = $Nome
    if ($n -match '(?i)\.ifc\.rvt$') { return $n.Substring(0, $n.Length - 8) }
    if ($n -match '(?i)\.rvt$')      { return $n.Substring(0, $n.Length - 4) }
    if ($n -match '(?i)\.ifc$')      { return $n.Substring(0, $n.Length - 4) }
    return [System.IO.Path]::GetFileNameWithoutExtension($n)
}

# Padrao de nomenclatura do escritorio.
# Ex.: 2001-EXE-ARQ-0001-MOD-R05
$RegexNomenclatura = '^(?<proj>\d{4})-(?<fase>[A-Z]{2,3})-(?<disc>[A-Z]{3})-(?<seq>\d{3,4})-(?<tipo>[A-Z]{3})-R(?<rev>\d{2})$'

function Test-Nomenclatura {
    param([string] $Chave)
    $m = [regex]::Match($Chave, $RegexNomenclatura)
    if ($m.Success) {
        return [pscustomobject]@{
            Conforme   = $true
            Projeto    = $m.Groups['proj'].Value
            Fase       = $m.Groups['fase'].Value
            Disciplina = $m.Groups['disc'].Value
            Sequencial = $m.Groups['seq'].Value
            Tipo       = $m.Groups['tipo'].Value
            Revisao    = [int] $m.Groups['rev'].Value
        }
    }
    # Tenta ao menos extrair disciplina e revisao de nomes fora do padrao.
    $disc = $null; $rev = $null
    $md = [regex]::Match($Chave, '(?i)\b(ARQ|ELE|ELET|EST|HID|CLI|SPK|GAS|TEL|AUT|FOR|GER|URB|PAI)\b')
    if ($md.Success) { $disc = $md.Groups[1].Value.ToUpper() }
    $mr = [regex]::Match($Chave, '(?i)[-_ ]R(\d{2})\b')
    if ($mr.Success) { $rev = [int] $mr.Groups[1].Value }
    return [pscustomobject]@{
        Conforme   = $false
        Projeto    = $null
        Fase       = $null
        Disciplina = $disc
        Sequencial = $null
        Tipo       = $null
        Revisao    = $rev
    }
}

function Get-ClasseArquivo {
    param([System.IO.FileInfo] $F)
    $n = $F.Name
    if ($n -match '(?i)\.ifc\.rvt$')                { return 'RVT_DE_IFC' }
    if ($n -match '(?i)\.\d{4}\.rvt$')              { return 'BACKUP_RVT' }
    if ($n -match '(?i)\.rvt$')                     { return 'RVT' }
    if ($n -match '(?i)\.ifc$')                     { return 'IFC' }
    if ($n -match '(?i)\.ifczip$')                  { return 'IFCZIP' }
    if ($n -match '(?i)\.ifc\.log$')                { return 'LOG_IFC' }
    if ($n -match '(?i)shared-parameters.*\.txt$')  { return 'SHAREDPARAM_IFC' }
    if ($n -match '(?i)\.pdf$')                     { return 'PDF' }
    if ($n -match '(?i)\.(nwc|nwd|nwf)$')           { return 'NAVISWORKS' }
    if ($n -match '(?i)\.(dwg|dxf)$')               { return 'CAD' }
    if ($n -match '(?i)\.(rfa|rte|rft)$')           { return 'FAMILIA_TEMPLATE' }
    return 'OUTRO'
}

# --------------------------------------------------------------------------
# Leitura do cabecalho / geometria do IFC (modo -Deep)
# --------------------------------------------------------------------------

function Read-IfcCabecalho {
    param([string] $Caminho)

    $schema     = 'desconhecido'
    $mvd        = 'nao declarada'
    $exportador = 'nao declarado'
    $linhas     = 0

    $sr = New-Object System.IO.StreamReader($Caminho, [System.Text.Encoding]::UTF8)
    try {
        while ($null -ne ($linha = $sr.ReadLine())) {
            $linhas++
            if ($linha -match "FILE_SCHEMA\s*\(\s*\(\s*'([^']+)'") { $schema = $Matches[1] }
            if ($linha -match "FILE_DESCRIPTION\s*\(\s*\(\s*'([^']*)'") { $mvd = $Matches[1] }
            if ($linha -match "FILE_NAME") {
                $mx = [regex]::Match($linha, "'([^']*(?:Revit|ArchiCAD|Tekla|Allplan|Vectorworks|Solibri|Navisworks|IFC Exporter|Civil 3D|SketchUp)[^']*)'", 'IgnoreCase')
                if ($mx.Success) { $exportador = $mx.Groups[1].Value }
            }
            if ($linha -match '^\s*DATA\s*;' -or $linhas -gt 400) { break }
        }
    }
    finally { $sr.Dispose() }

    return [pscustomobject]@{
        Schema     = $schema
        MVD        = $mvd
        Exportador = $exportador
    }
}

function Measure-IfcGeometria {
    param([string] $Caminho)

    $tokens = @{
        'IFCEXTRUDEDAREASOLID'     = 0   # solido parametrico (leve)
        'IFCBOOLEANCLIPPINGRESULT' = 0   # solido recortado  (leve)
        'IFCMAPPEDITEM'            = 0   # instanciacao reaproveitada (otimo)
        'IFCFACETEDBREP'           = 0   # malha / brep facetado (pesado)
        'IFCTRIANGULATEDFACESET'   = 0   # tesselacao IFC4     (pesado)
        'IFCPOLYGONALFACESET'      = 0   # tesselacao IFC4     (pesado)
        'IFCADVANCEDBREP'          = 0   # brep NURBS          (pesado)
        'IFCPROPERTYSINGLEVALUE'   = 0   # volume de propriedades
        'IFCSHAPEREPRESENTATION'   = 0
    }
    $chaves = @($tokens.Keys)

    $sr = New-Object System.IO.StreamReader($Caminho, [System.Text.Encoding]::UTF8)
    try {
        while ($null -ne ($linha = $sr.ReadLine())) {
            if ($linha.Length -lt 8) { continue }
            foreach ($k in $chaves) {
                if ($linha.Contains($k)) { $tokens[$k] = $tokens[$k] + 1 }
            }
        }
    }
    finally { $sr.Dispose() }

    $leves   = $tokens['IFCEXTRUDEDAREASOLID'] + $tokens['IFCBOOLEANCLIPPINGRESULT']
    $pesados = $tokens['IFCFACETEDBREP'] + $tokens['IFCTRIANGULATEDFACESET'] +
               $tokens['IFCPOLYGONALFACESET'] + $tokens['IFCADVANCEDBREP']
    $total   = $leves + $pesados
    $pctMalha = 0
    if ($total -gt 0) { $pctMalha = [math]::Round(100.0 * $pesados / $total, 1) }

    return [pscustomobject]@{
        Contagens     = $tokens
        SolidosLeves  = $leves
        MalhasPesadas = $pesados
        PercentMalha  = $pctMalha
    }
}

# --------------------------------------------------------------------------
# 0. Validacao e inventario
# --------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Raiz)) {
    Write-Host "Caminho nao encontrado: $Raiz" -ForegroundColor Red
    exit 1
}
$Raiz = (Resolve-Path -LiteralPath $Raiz).Path

Write-Secao "AUDITORIA DE VINCULOS  -  $(Split-Path $Raiz -Leaf)"
Write-Host "  Raiz : $Raiz"
Write-Host "  Data : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
Write-Host "  Modo : $(if ($Deep) { 'completo (-Deep)' } else { 'rapido' })"

$arquivos = Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force -ErrorAction SilentlyContinue

$inventario = foreach ($f in $arquivos) {
    $chave = Get-ChaveVinculo $f.Name
    $nom   = Test-Nomenclatura $chave
    [pscustomobject]@{
        Nome         = $f.Name
        Chave        = $chave
        Classe       = Get-ClasseArquivo $f
        MB           = ConvertTo-MB $f.Length
        Bytes        = $f.Length
        Modificado   = $f.LastWriteTime
        Pasta        = $f.DirectoryName.Replace($Raiz, '.')
        Caminho      = $f.FullName
        Conforme     = $nom.Conforme
        Disciplina   = $nom.Disciplina
        Revisao      = $nom.Revisao
        Fase         = $nom.Fase
    }
}

if (-not $inventario) {
    Write-Achado 'ATENCAO' 'Nenhum arquivo encontrado sob a raiz informada.'
    exit 0
}

# --------------------------------------------------------------------------
# 1. Inventario por classe
# --------------------------------------------------------------------------

Write-Secao '1. INVENTARIO POR TIPO REAL DE ARQUIVO'
Write-Host '  (o Explorer esconde extensoes conhecidas: "X.ifc" com icone do Revit e, na verdade, X.ifc.rvt)' -ForegroundColor DarkGray
Write-Host ''

$inventario |
    Group-Object Classe |
    Sort-Object { ($_.Group | Measure-Object Bytes -Sum).Sum } -Descending |
    ForEach-Object {
        [pscustomobject]@{
            Classe = $_.Name
            Qtd    = $_.Count
            TotalMB = [math]::Round((($_.Group | Measure-Object Bytes -Sum).Sum) / 1MB, 1)
        }
    } | Format-Table -AutoSize

$totalMB = [math]::Round((($inventario | Measure-Object Bytes -Sum).Sum) / 1MB, 1)
Write-Host "  Total geral: $totalMB MB em $($inventario.Count) arquivos"

# --------------------------------------------------------------------------
# 2. Pareamento IFC -> RVT e taxa de inflacao
# --------------------------------------------------------------------------

Write-Secao '2. CONVERSAO IFC -> RVT  (o IFC engorda ou emagrece?)'

$ifcs    = $inventario | Where-Object Classe -eq 'IFC'
$rvtIfcs = $inventario | Where-Object Classe -eq 'RVT_DE_IFC'

$pares = foreach ($ifc in $ifcs) {
    $par = $rvtIfcs | Where-Object { $_.Chave -eq $ifc.Chave } | Select-Object -First 1
    if ($par) {
        $ratio = [math]::Round(100.0 * ($par.Bytes - $ifc.Bytes) / $ifc.Bytes, 1)
        [pscustomobject]@{
            Modelo      = $ifc.Chave
            IFC_MB      = $ifc.MB
            RVT_MB      = $par.MB
            Delta_Pct   = $ratio
            IFC_Data    = $ifc.Modificado
            RVT_Data    = $par.Modificado
            Desatualiz  = ($ifc.Modificado -gt $par.Modificado)
        }
    }
}

if ($pares) {
    $pares | Format-Table Modelo, IFC_MB, RVT_MB, @{N='Delta_%';E={ '{0:+0.0;-0.0}' -f $_.Delta_Pct }}, Desatualiz -AutoSize

    $mediaDelta = [math]::Round(($pares | Measure-Object Delta_Pct -Average).Average, 1)
    if ($mediaDelta -gt 0) {
        Write-Achado 'INFO' "Na media o RVT gerado ficou $mediaDelta% MAIOR que o IFC de origem."
    } else {
        Write-Achado 'INFO' "Na media o RVT gerado ficou $([math]::Abs($mediaDelta))% MENOR que o IFC de origem."
    }
    foreach ($p in $pares) {
        if ($p.Delta_Pct -gt 80) {
            Write-Achado 'ATENCAO' "$($p.Modelo): +$($p.Delta_Pct)% na conversao. Indicio forte de geometria em malha (Brep/Tessellation) no IFC. Rode com -Deep."
        }
        if ($p.Desatualiz) {
            Write-Achado 'CRITICO' "$($p.Modelo): o .ifc e mais NOVO que o .ifc.rvt. O vinculo em uso nao reflete o IFC atual."
        }
    }
} else {
    Write-Achado 'INFO' 'Nenhum par IFC/.ifc.rvt encontrado nesta raiz.'
}

# --------------------------------------------------------------------------
# 3. Duplicidade por hash
# --------------------------------------------------------------------------

Write-Secao '3. ARQUIVOS DUPLICADOS (mesmo conteudo, nomes diferentes)'

$candidatos = $inventario | Where-Object { $_.Classe -in @('RVT', 'RVT_DE_IFC', 'IFC') -and $_.Bytes -gt 1MB }
$porTamanho = $candidatos | Group-Object Bytes | Where-Object Count -gt 1

$duplicados = @()
foreach ($g in $porTamanho) {
    foreach ($item in $g.Group) {
        $h = (Get-FileHash -LiteralPath $item.Caminho -Algorithm SHA256).Hash
        $duplicados += [pscustomobject]@{ Nome = $item.Nome; MB = $item.MB; Hash = $h; Pasta = $item.Pasta }
    }
}

$gruposHash = $duplicados | Group-Object Hash | Where-Object Count -gt 1
if ($gruposHash) {
    foreach ($g in $gruposHash) {
        $desperdicio = [math]::Round($g.Group[0].MB * ($g.Count - 1), 1)
        Write-Achado 'CRITICO' "$($g.Count) copias identicas de $($g.Group[0].MB) MB  ->  desperdicio de $desperdicio MB"
        $g.Group | ForEach-Object { Write-Host "             $($_.Pasta)\$($_.Nome)" -ForegroundColor DarkGray }
    }
} else {
    if ($porTamanho) {
        Write-Achado 'OK' 'Ha arquivos de mesmo tamanho, mas nenhum e byte-a-byte identico.'
        foreach ($g in $porTamanho) {
            Write-Achado 'ATENCAO' "Mesmo tamanho ($($g.Group[0].MB) MB), conteudo diferente: $(($g.Group.Nome) -join '  |  ')"
        }
    } else {
        Write-Achado 'OK' 'Nenhuma duplicidade detectada.'
    }
}

# --------------------------------------------------------------------------
# 4. Nomenclatura
# --------------------------------------------------------------------------

Write-Secao '4. CONFORMIDADE DE NOMENCLATURA'
Write-Host '  Padrao esperado: PROJ-FASE-DISC-SEQ-TIPO-Rxx   (ex.: 2001-EXE-ARQ-0001-MOD-R05)' -ForegroundColor DarkGray
Write-Host ''

$modelos = $inventario | Where-Object Classe -in @('RVT', 'RVT_DE_IFC', 'IFC')
$foraPadrao = $modelos | Where-Object { -not $_.Conforme }
$extensaoDupla = $inventario | Where-Object Classe -eq 'RVT_DE_IFC'

foreach ($f in $foraPadrao) {
    $motivo = 'nao bate com o padrao PROJ-FASE-DISC-SEQ-TIPO-Rxx'
    if ($f.Chave -match '[\(\)]')   { $motivo = 'parenteses/carimbo de data no nome (exportacao automatica de terceiro)' }
    elseif ($f.Chave -notmatch '-') { $motivo = 'nome livre, sem codigo de projeto/disciplina/revisao' }
    Write-Achado 'ATENCAO' "$($f.Nome)  ->  $motivo"
}

foreach ($f in $extensaoDupla) {
    Write-Achado 'ATENCAO' "$($f.Nome)  ->  extensao dupla .ifc.rvt: arquivo gerado pelo importador e nunca renomeado. Sera SOBRESCRITO na proxima importacao do mesmo IFC."
}

if (-not $foraPadrao -and -not $extensaoDupla) {
    Write-Achado 'OK' 'Todos os modelos seguem a nomenclatura.'
}

# --------------------------------------------------------------------------
# 5. PDF de referencia x revisao do modelo
# --------------------------------------------------------------------------

Write-Secao '5. REFERENCIAS PDF x REVISAO DO MODELO'

$pdfs = $inventario | Where-Object Classe -eq 'PDF'
if ($pdfs) {
    $revModelo = @{}
    foreach ($m in ($modelos | Where-Object { $_.Disciplina -and $null -ne $_.Revisao })) {
        $d = $m.Disciplina
        if ((-not $revModelo.ContainsKey($d)) -or ($m.Revisao -gt $revModelo[$d])) {
            $revModelo[$d] = $m.Revisao
        }
    }

    foreach ($p in $pdfs) {
        $d = $p.Disciplina
        if (-not $d) {
            Write-Achado 'ATENCAO' "$($p.Nome): nao da para identificar a disciplina pelo nome."
            continue
        }
        if ($null -eq $p.Revisao) {
            Write-Achado 'ATENCAO' "$($p.Nome): sem revisao (Rxx) no nome. Impossivel garantir aderencia ao modelo."
            continue
        }
        if ($revModelo.ContainsKey($d)) {
            if ($p.Revisao -eq $revModelo[$d]) {
                Write-Achado 'OK' "$($p.Nome): R$('{0:00}' -f $p.Revisao) confere com o modelo $d R$('{0:00}' -f $revModelo[$d])."
            } elseif ($p.Revisao -lt $revModelo[$d]) {
                Write-Achado 'CRITICO' "$($p.Nome): PDF em R$('{0:00}' -f $p.Revisao) contra modelo $d R$('{0:00}' -f $revModelo[$d]). Referencia SUPERADA."
            } else {
                Write-Achado 'CRITICO' "$($p.Nome): PDF em R$('{0:00}' -f $p.Revisao) e mais novo que o modelo $d R$('{0:00}' -f $revModelo[$d]). O modelo esta atrasado."
            }
        } else {
            Write-Achado 'ATENCAO' "$($p.Nome): nao ha modelo da disciplina $d nesta raiz para comparar."
        }
    }
} else {
    Write-Achado 'INFO' 'Nenhum PDF encontrado sob esta raiz.'
}

# --------------------------------------------------------------------------
# 6. Higiene de caminho
# --------------------------------------------------------------------------

Write-Secao '6. HIGIENE DE CAMINHO E ARMAZENAMENTO'

if ($Raiz -match '(?i)OneDrive|Dropbox|Google Drive|iCloud') {
    Write-Achado 'CRITICO' 'Projeto dentro de pasta sincronizada (OneDrive/Dropbox/GDrive). Revit + sync = travamento de arquivo, .rvt corrompido e lentidao a cada salvamento.'
}
if ($Raiz -match '(?i)\\Desktop\\|\\Area de Trabalho\\') {
    Write-Achado 'ATENCAO' 'Projeto na Area de Trabalho: caminho longo e alvo de backup automatico.'
}

$acentuados = $inventario | Where-Object { $_.Caminho -match "[^\u0000-\u007F]" }
if ($acentuados) {
    $pastasAcent = $acentuados | ForEach-Object { $_.Pasta } | Sort-Object -Unique
    Write-Achado 'ATENCAO' "$($acentuados.Count) arquivos em caminho com acento/cedilha. Quebra Dynamo, Python, ACC e linha de comando."
    $pastasAcent | Select-Object -First 8 | ForEach-Object { Write-Host "             $_" -ForegroundColor DarkGray }
}

$apostrofo = $inventario | Where-Object { $_.Caminho -match "'" }
if ($apostrofo) {
    Write-Achado 'CRITICO' "$($apostrofo.Count) arquivos em caminho com apostrofo, no estilo da pasta IFC-apostrofo-s. Quebra scripts, Dynamo e automacao."
}

$longos = $inventario | Where-Object { $_.Caminho.Length -gt $LimiteCaminho }
if ($longos) {
    Write-Achado 'ATENCAO' "$($longos.Count) caminhos acima de $LimiteCaminho caracteres (limite classico do Windows = 260)."
    $longos | Sort-Object { $_.Caminho.Length } -Descending | Select-Object -First 3 |
        ForEach-Object { Write-Host "             [$($_.Caminho.Length)] $($_.Caminho)" -ForegroundColor DarkGray }
}

# --------------------------------------------------------------------------
# 7. Peso morto
# --------------------------------------------------------------------------

Write-Secao '7. PESO MORTO NA PASTA DE VINCULOS'

$morto = $inventario | Where-Object Classe -in @('BACKUP_RVT', 'LOG_IFC', 'SHAREDPARAM_IFC')
if ($morto) {
    $morto | Group-Object Classe | ForEach-Object {
        $mb = [math]::Round((($_.Group | Measure-Object Bytes -Sum).Sum) / 1MB, 2)
        Write-Achado 'ATENCAO' "$($_.Name): $($_.Count) arquivos, $mb MB"
    }
}

$sp = $inventario | Where-Object Classe -eq 'SHAREDPARAM_IFC'
foreach ($s in $sp) {
    $linhas = 0
    try { $linhas = (Get-Content -LiteralPath $s.Caminho -ErrorAction Stop | Measure-Object -Line).Lines } catch { }
    if ($linhas -gt 150) {
        Write-Achado 'ATENCAO' "$($s.Nome): ~$linhas parametros compartilhados criados na importacao. Cada um vira parametro de projeto no RVT gerado e engorda o vinculo."
    }
}

$backups = $inventario | Where-Object Classe -eq 'BACKUP_RVT'
if ($backups) {
    $mbB = [math]::Round((($backups | Measure-Object Bytes -Sum).Sum) / 1MB, 1)
    Write-Achado 'ATENCAO' "$($backups.Count) backups .0001.rvt ocupando $mbB MB dentro da area de vinculos. Backup nao deve morar na pasta compartilhada."
}
if (-not $morto) { Write-Achado 'OK' 'Sem peso morto relevante.' }

# --------------------------------------------------------------------------
# 8. Analise profunda do IFC (-Deep)
# --------------------------------------------------------------------------

if ($Deep -and $ifcs) {
    Write-Secao '8. DENTRO DO IFC: ESQUEMA, MVD E REPRESENTACAO GEOMETRICA'

    foreach ($ifc in $ifcs) {
        Write-Host ''
        Write-Host "  >> $($ifc.Nome)  ($($ifc.MB) MB)" -ForegroundColor White

        $cab = Read-IfcCabecalho $ifc.Caminho
        Write-Host "     Esquema    : $($cab.Schema)"
        Write-Host "     MVD        : $($cab.MVD)"
        Write-Host "     Exportador : $($cab.Exportador)"

        if ($cab.Schema -match '(?i)IFC4') {
            Write-Achado 'ATENCAO' 'IFC4: se o MVD for Reference View, a geometria vem tesselada (malha) por definicao -> RVT pesado e lento.'
        } elseif ($cab.Schema -match '(?i)IFC2X3') {
            Write-Achado 'OK' 'IFC2x3 Coordination View e o formato com melhor leitura pelo importador do Revit.'
        }

        Write-Host '     Lendo geometria...' -ForegroundColor DarkGray
        $geo = Measure-IfcGeometria $ifc.Caminho

        Write-Host "     Solidos parametricos : $($geo.SolidosLeves)"
        Write-Host "     Malhas / Brep        : $($geo.MalhasPesadas)   ($($geo.PercentMalha)% do total)"
        Write-Host "     IfcMappedItem        : $($geo.Contagens['IFCMAPPEDITEM'])  (reaproveitamento de geometria)"
        Write-Host "     Propriedades         : $($geo.Contagens['IFCPROPERTYSINGLEVALUE'])"

        if ($geo.PercentMalha -gt 50) {
            Write-Achado 'CRITICO' 'Maioria da geometria vem como malha. Peca o reexport em IFC2x3 CV2.0 com solidos (SweptSolid/Clipping).'
        } elseif ($geo.PercentMalha -gt 20) {
            Write-Achado 'ATENCAO' 'Parte relevante da geometria vem como malha.'
        } else {
            Write-Achado 'OK' 'Geometria predominantemente parametrica (leve).'
        }

        if ($geo.Contagens['IFCPROPERTYSINGLEVALUE'] -gt 200000) {
            Write-Achado 'ATENCAO' 'Volume enorme de propriedades. Desligue "Exportar todas as propriedades / property sets do Revit" na origem.'
        }
        if ($geo.Contagens['IFCMAPPEDITEM'] -lt ($geo.SolidosLeves / 10)) {
            Write-Achado 'ATENCAO' 'Pouco IfcMappedItem: a geometria foi explodida por instancia em vez de reaproveitada. Inflaciona o arquivo.'
        }
    }
} elseif ($ifcs) {
    Write-Host ''
    Write-Host '  (rode novamente com -Deep para abrir os IFCs e diagnosticar esquema e geometria)' -ForegroundColor DarkGray
}

# --------------------------------------------------------------------------
# 9. Exportacao
# --------------------------------------------------------------------------

if ($CsvOut) {
    $inventario | Sort-Object Bytes -Descending |
        Select-Object Classe, Nome, MB, Modificado, Conforme, Disciplina, Revisao, Pasta |
        Export-Csv -LiteralPath $CsvOut -NoTypeInformation -Encoding UTF8
    Write-Host ''
    Write-Host "  Inventario exportado para: $CsvOut" -ForegroundColor Green
}

Write-Host ''
Write-Host ('=' * 78) -ForegroundColor DarkCyan
Write-Host '  Fim da auditoria. Nenhum arquivo foi alterado.' -ForegroundColor DarkCyan
Write-Host ('=' * 78) -ForegroundColor DarkCyan
Write-Host ''
