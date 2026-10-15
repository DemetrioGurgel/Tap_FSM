# Tap_FSM – Controlador TAP (IEEE 1149.1)

Controlador TAP de 16 estados em SystemVerilog, desenvolvido pelo Grupo 2 (JTAG e boundary scan) na Fase 2 da Trilha Design For Test da residência CI Expert/UFCG.

Este é o **módulo de estudo** da segunda semana: a máquina de estados do TAP e os indicadores de estado, sem registrador de instrução, registradores de dados ou boundary scan.

## Referência

IEEE Std 1149.1-2001, *IEEE Standard Test Access Port and Boundary-Scan Architecture*:

| Item | Onde está na norma |
|---|---|
| Diagrama de estados | Figura 6-1, p. 19 |
| Transições na borda de subida de TCK | Regra 6.1.1 b), p. 19 |
| Descrição de cada estado | Seção 6.1.2, p. 20–23 |
| Codificação dos estados | Tabela 6-3, p. 31 |
| Reset assíncrono por TRST* | Regra 6.3.1 c), p. 31 |

## Estrutura do repositório

```
Tap_FSM/
├── rtl/
│   ├── tap_state_pkg.sv     # 16 estados com a codificação da Tabela 6-3
│   └── tap_fsm.sv           # controlador TAP
├── tb/                      # testbench (em desenvolvimento)
├── docs/
│   └── diagrama_estados_tap.pdf
├── logs/                    # logs de compilação e simulação
└── work/                    # área de trabalho das ferramentas (ignorada pelo Git)
```

## Interface do módulo `tap_fsm`

| Porta | Direção | Largura | Descrição |
|---|---|---|---|
| `tck` | entrada | 1 | Relógio de teste; a FSM muda de estado na borda de subida |
| `trst_n` | entrada | 1 | Reset assíncrono, ativo baixo; leva a FSM a Test-Logic-Reset |
| `tms` | entrada | 1 | Seleção de modo, amostrada na borda de subida de TCK |
| `test_logic_reset` | saída | 1 | Nível alto em Test-Logic-Reset |
| `capture_dr`, `shift_dr`, `update_dr` | saída | 1 cada | Nível alto em Capture-DR, Shift-DR e Update-DR |
| `capture_ir`, `shift_ir`, `update_ir` | saída | 1 cada | Nível alto em Capture-IR, Shift-IR e Update-IR |
| `state_o` | saída | 4 | Estado atual (`tap_state_t`), apenas para verificação |

As saídas dependem só do estado atual (FSM de Moore): mudam logo após a borda de subida de TCK e ficam estáveis até a próxima.

## Convenções do módulo de estudo

- TCK com período de 20 ns.
- O mestre JTAG altera TMS na borda de descida de TCK; a FSM o amostra na borda de subida.
- `trst_n` e `state_o` são convenções deste módulo, não contrato da plataforma. A existência de TRST* na plataforma depende de definição do instrutor.

## Como compilar (servidor do laboratório)

Em todo terminal novo, carregue o ambiente da Synopsys:

```
source /Tools/synopsys-scripts/snps.sh
```

Da raiz do repositório, compile o RTL (o pacote vem antes do módulo):

```
set -o pipefail
vcs -full64 -sverilog rtl/tap_state_pkg.sv rtl/tap_fsm.sv -top tap_fsm -Mdir=work/vcs/csrc -o work/vcs/simv_tap 2>&1 | tee logs/vcs_tap_fsm_compile.log
```

Procure erros e avisos no log (a busca simples por "error" dá falso positivo por causa da biblioteca `-lerrorinf`):

```
grep -n "Error-\[\|Warning-\[\|Lint-\[" logs/vcs_tap_fsm_compile.log
```

O resultado esperado é nenhuma linha.

Observações:

- A opção `-full64` é obrigatória neste servidor. Sem ela, o VCS procura executáveis de 32 bits que não estão instalados.
- Arquivos gerados pelas ferramentas ficam em `work/`, que não é versionado.

## Situação atual

| Item | Situação |
|---|---|
| RTL da FSM de 16 estados | Concluído |
| Compilação no VCS X-2025.06-SP2 | Sem erros e sem avisos (`logs/vcs_tap_fsm_compile.log`) |
| Diagrama de estados | Concluído (`docs/diagrama_estados_tap.pdf`) |
| Tabela de transições esperadas | Em revisão |
| Testbench autochecável (execução positiva e controle negativo) | Em desenvolvimento |
