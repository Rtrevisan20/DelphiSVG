# DelphiSVG

Biblioteca SVG para Delphi, originalmente por Martin Walter
(<https://development.mwcs.de/svgimage.html>), com port para **Lazarus/Free Pascal**
neste repositório (branch `port-lazarus`).

O mesmo código-fonte roda nas duas IDEs:

- **Delphi** (XE2+, testado com Delphi 12.2 Athens) — renderização via **GDI+**;
- **Lazarus/FPC** (FPC 3.2.2+, testado com Lazarus 4.8) — renderização via
  **`TPainterLCL`** (TCanvas, cross-platform) ou, no Windows, também via GDI+.

## Estrutura

```
src\svg\          núcleo portátil (TSVG, parsing XML, paths, cores, texto)
src\gdip\         helpers GDI+ (GDIPAPI/GDIPOBJ e amigos — backend Delphi/Windows)
src\painter\      camada de abstração TPainter + TPainterGdiPlus + TPainterLCL
Packages\Delphi\  pacote Delphi (SVGPackage.dpk/dproj/groupproj) + vcl\ e fmx\
Packages\Lazarus\ pacotes .lpk (components\, delphisvg.lpk) + scripts e demos LCL
tests\examples\   SVGs de teste (34 arquivos usados pela suíte)
tests\lcl\        harnesses e scripts de teste/validação do lado Lazarus
baseline\         gerador da linha de base de pixels (Delphi/GDI+ → PNG)
validation\       suíte de validação Fase 5 (comparação pixel/integração/perf)
```

Detalhes:

- `src\painter\Painter.pas` — contrato `TPainter` (portável);
- `src\painter\PainterGdiPlus.pas` — backend GDI+ (Delphi/Lazarus-Windows);
- `src\painter\PainterLCL.pas` — backend LCL (TCanvas, cross-platform);
- `Packages\Lazarus\components\` — componentes LCL (`TSVGImage`, `TSVGImageList`,
  `TSVGSpeedButton`) + editor design-time + ícones;
- `Packages\Lazarus\packages\` — `delphisvg.lpk` e `delphisvg_dsgn.lpk`;
- `Packages\Lazarus\examples\SVGDemo\` — demo Lazarus (`.lpi`).

## Instalação — Delphi

1. Abra `Packages\Delphi\SVGPackage.dpk` no Delphi.
2. Compile e instale o package.
3. Componentes na página **SVG**: `TSVGImageList`, `TSVGSpeedButton`, `TSVGImage`.
4. Demo: `Packages\Delphi\vcl\SvgViewer.dpr`; linha de base:
   `baseline\RenderBaseline.dpr`
   (`dcc32 -B -CC -U"..\src\svg;..\src\gdip;..\src\painter" RenderBaseline.dpr`).

## Instalação — Lazarus

1. Instale o pacote de runtime/design `Packages\Lazarus\packages\delphisvg.lpk`
   (Package → Open, Compile + Use) — registra os componentes e o formato de
   arquivo SVG (`TPicture.RegisterFileFormat`).
2. Para o editor de coleção do `TSVGImageList` no design-time, instale também
   `Packages\Lazarus\packages\delphisvg_dsgn.lpk`.
3. Demo: `Packages\Lazarus\examples\SVGDemo\SVGDemo.lpi`.
4. Teste de renderização: `tests\lcl\run_lcltest.bat` / `runall_lcl.bat`
   (34/34 SVGs).

Notas FPC:

- O search path do package já inclui
  `$(FPCDir)\units\$(TargetCPU)-$(TargetOS)\vcl-compat`
  (necessário para `System.NetEncoding`).
- As units portáveis usam `{$IFDEF FPC} ... {$ENDIF}` nos `uses` (nomes de unit
  sem namespace); não faça mapeamento manual.
- `lazbuild` neste ambiente de CI/host não valida pacotes; valide com
  `fpc -Mdelphi` direto + checagem XML do `.lpk` (ver abaixo).

## Arquitetura

O núcleo `src\svg\` não conhece GDI+: toda pintura passa pela interface `TPainter`
(`src\painter\Painter.pas`). Backends registrados por fábrica/registro em
`initialization`:

- `TPainterGdiPlus` — Delphi (e Lazarus-Windows se você o linkar);
- `TPainterLCL` — Lazarus (qualquer widgetset).

O backend ativo é escolhido pela ordem de inicialização das units no `.dpr`/`.lpr`
(a unit linkada diretamente pelo programa inicializa por último e vence o
registro). Não linkar os dois backends no mesmo exe sem uma estratégia explícita.

Serviços parse-time (`TPainterMeasure`, fábricas de path/imagem) permitem ao
núcleo montar glyphs e carregar imagens sem um canvas.

## Validação (Fase 5)

Ordem de execução (tudo a partir da raiz, PowerShell/cmd):

| Etapa | Comando | Saída |
|---|---|---|
| Baseline Delphi (26 PNGs) | `cd baseline && RenderBaseline.exe` | `baseline\png\` |
| Renders LCL (34 BMPs) | `tests\lcl\run_lclrenders.bat` | `tests\lcl\lcl_renders\` |
| Comparação pixel-a-pixel | `pwsh -File validation\compare_renders.ps1 -DiffImages` | `validation\report\compare_report.txt`, `fidelity.csv`, `diff\*.diff.png` |
| Integração (2 IDEs) | `validation\run_validation.bat` | `validation\report\integration_report.txt` |
| Performance/memória | `pwsh -File validation\run_perf.ps1` | `validation\report\perf_report.txt` |

Tudo de uma vez: `validation\run_validation.bat` (compila os harnesses Delphi
(dcc32) e LCL (fpc), renderiza e compara).

Critérios da comparação pixel: `exact` (delta 0), `near` (≤32 por canal),
`far` (>32). Classe `IDENTICAL` (exact 100%), `NEAR` (exact+near ≥ 99,5%),
senão `DIVERGENT`. A série histórica fica em `fidelity.csv`.

## Limitações conhecidas do backend LCL

Consistentes com a comparação Fase 5 (média ~83% exact vs GDI+; ver
`validation\report\compare_report.txt`):

- sem antialiasing em paths (bordas duras);
- `TPainterText` usa caixas placeholder (sem contorno de texto em path);
- gradiente radial aproximado (anéis concêntricos);
- imagem desenhada sem opacidade (avançar para `TBitmap` + alpha é trabalho futuro).

O backend GDI+ (Delphi) é a referência de fidelidade; os 26 PNGs de
`baseline\png\` são idênticos ao snapshot pré-refatoração.

## Licença

Código original de Martin Walter (ver repositório upstream); port deste
repositório segue a mesma licença do projeto original. Units `GDIPAPI`/`GDIPOBJ`
são de hgourvest (MPL).