# Logica de verificacao do controlador TAP

Este documento descreve a logica de `tb/tb_tap_fsm.sv`. A referencia das transicoes
e a Figura 6-1 da IEEE Std 1149.1-2001. Os requisitos da campanha estao na
secao do Grupo 2 em `atividades_semana02.pdf`.

## 1. Objetivos da verificacao

O circuito sob teste (`dut`) e a maquina TAP de 16 estados em `rtl/tap_fsm.sv`.
O testbench precisa mostrar que:

1. Cada estado segue o destino correto para TMS=0 e para TMS=1: **32 pares
   estado/TMS** ao todo.
2. Cinco subidas consecutivas de TCK com TMS=1 levam a
   `Test-Logic-Reset` a partir de cada estado conhecido.
3. TMS=0 mantem a maquina em `Run-Test/Idle`.
4. Os indicadores de Capture, Shift e Update de DR e IR, alem de
   `test_logic_reset`, concordam com o estado atual.
5. E possivel percorrer os ramos DR e IR, entrar em Pause e retomar Shift.
6. A porta `trst_n` deste modulo de estudo provoca reset assincrono.
7. O verificador rejeita uma expectativa propositalmente errada em uma
   execucao separada.

O teste observa estados e indicadores. Este modulo nao contem TDI, TDO,
registradores de dados ou registrador de instrucoes; portanto, a campanha
nao verifica bits deslocados nem conformidade completa com a norma.

## 2. Modelo esperado e circuito sob teste

O `dut` recebe `tck`, `tms` e `trst_n`. Ele devolve `state_o` e sete
indicadores. O testbench mantem um `expected_state` proprio e o atualiza
pela tabela `next_expected[estado][tms]`.

```text
                       TMS aplicado pelo mestre
                                 |
                  +--------------+--------------+
                  |                             |
          Tabela de referencia                DUT RTL
          + estado esperado                + estado real
                  |                             |
                  +-------- comparacao ---------+
                            estado e indicadores
```

Os IDs locais `TLR=0`, `IDLE=1`, etc. organizam o modelo esperado. Eles
**nao sao** a codificacao de 4 bits da porta do RTL. Por exemplo, o ID local
de `Run-Test/Idle` e `1`, mas a porta `state_o` deve valer `4'hC` nesse
estado. A tabela `observed_code` faz essa traducao apenas na hora de
comparar. Ela nao participa do calculo do proximo estado.

O testbench nao importa `tap_state_pkg` e nao usa `dut.state` nem
`dut.next_state` para calcular a resposta esperada. Isso evita que um erro
na logica de transicao do RTL seja copiado automaticamente pelo oraculo.
Ainda assim, a tabela manual precisa de revisao humana contra a Figura 6-1:
independencia do codigo nao dispensa conferencia da referencia.

## 3. Inicializacao da referencia

`initialize_reference` preenche quatro estruturas:

| Estrutura | Papel |
|---|---|
| `next_expected[16][2]` | Destino esperado para cada estado e TMS |
| `observed_code[16]` | Codigo de 4 bits esperado na porta `state_o` |
| `state_name[16]` | Nome legivel usado nos logs |
| `reset_path[16]` | Sequencia legal de TMS para chegar ao estado a partir de reset |

Por exemplo, a linha do estado `IDLE` define:

```systemverilog
next_expected[IDLE][0] = IDLE;
next_expected[IDLE][1] = SEL_DR;
```

Assim, se a referencia esta em Idle e o mestre aplica TMS=0, ela continua
em Idle. Com TMS=1, espera `Select-DR-Scan`. A estrutura
`transition_hits[16][2]` comeca zerada e conta quantas vezes cada par
estado/TMS passou por uma comparacao.

## 4. Relogio, estimulo e momento da comparacao

`always #10 tck = ~tck` produz um TCK de periodo **20 ns**. Cada chamada a
`jtag_cycle(tms_value)` faz o seguinte:

```text
borda de descida             borda de subida       1 ns depois
      |                            |                    |
      +-- altera TMS              +-- DUT amostra TMS  +-- compara
      +-- 1 ns depois: confirma       e registra estado    estado e flags
          que estado/flags antigos     esperado novo       +-- conta cobertura
          ainda estao estaveis                             +-- imprime TRACE
```

Na descida, `tms = tms_value` prepara o sinal para a proxima subida. A
comparacao `before_rising_edge` verifica que o estado e os indicadores
continuam com os valores antigos. Na subida, `expected_state` recebe
`next_expected[previous_state][tms_value]`. O `#1` seguinte permite que a
atribuicao nao bloqueante do registrador RTL e as saidas combinacionais
assentem antes da comparacao `after_rising_edge`. Esse atraso e uma
convencao da bancada de simulacao, nao uma especificacao de timing fisico.

`check_observation` compara `state_o` com `observed_code[expected_state]`
usando `!==`. Esse operador acusa tambem X ou Z inesperado. Em seguida,
monta `expected_flags` a partir do estado esperado e compara os sete bits
com as saidas reais: `test_logic_reset`, `capture_dr`, `shift_dr`,
`update_dr`, `capture_ir`, `shift_ir` e `update_ir`.

Se uma comparacao falha, a simulacao emite a causa e para. So depois de
passar pelas comparacoes o par `previous_state/TMS` ganha um `hit`, o
contador `cycles` aumenta e a linha `TRACE` e impressa.

## 5. Como o mestre chega a cada estado

`reset_by_tms` aplica cinco ciclos com TMS=1. Em seguida,
`reach_state(target)` envia a sequencia guardada em `reset_path[target]`.
Cada caractere `0` ou `1` causa uma chamada de `jtag_cycle`. Nao existe
`force` nem escrita direta no registrador de estado do DUT.

Exemplo: para alcancar `Pause-DR`, o caminho e `01010`:

```text
Test-Logic-Reset --0--> Run-Test/Idle --1--> Select-DR-Scan
                 --0--> Capture-DR --1--> Exit1-DR --0--> Pause-DR
```

O caminho e testado passo a passo. Se o DUT errar antes de chegar ao alvo,
a primeira transicao incorreta ja interrompe a execucao.

## 6. Execucao positiva

O bloco `campaign` comeca com um pulso de `trst_n` para definir o estado
inicial. Depois executa as fases abaixo:

| `phase` no log | Procedimento | Resultado buscado |
|---|---|---|
| `all_transitions` | Para cada um dos 16 estados, `reach_state` e um ciclo final com TMS=0; repete com TMS=1 | Cobrir os 32 pares |
| `reset_recovery` | Chega a cada estado e aplica cinco TMS=1 | Reset a partir das 16 origens |
| `idle_hold` | Chega a Idle e aplica dez TMS=0 | Dez permanencias em Idle |
| `dr_pause_resume` | Envia `010010100110` apos reset | DR, Pause, retomada de Shift e volta a Idle |
| `ir_pause_resume` | Envia `0110010100110` apos reset | IR, Pause, retomada de Shift e volta a Idle |
| `async_reset` | Chega a cada estado e pulsa `trst_n` fora da subida | Reset assincrono nas 16 origens |

`pulse_trst` baixa `trst_n` entre bordas, muda a referencia imediatamente
para reset e compara a saida antes da proxima subida. Depois solta
`trst_n` e confere que o estado continua em reset naquele instante. Durante
a liberacao, TMS e mantido em 1. Esse teste cobre o comportamento da porta
presente no modulo de estudo; a presenca de TRST na plataforma final ainda
depende do contrato do instrutor.

No fim, o testbench imprime uma linha `COVERAGE` para cada um dos 32 pares.
`hits` maior que zero indica que aquele par passou ao menos uma vez. A
contagem inclui ciclos de navegacao e reset, pois todos passam pelo mesmo
`jtag_cycle` e sao conferidos. O teste so imprime `TAP_POSITIVE_PASS` se
`covered==32`, `recovery_cases==16` e `async_reset_cases==16`. Qualquer
divergencia anterior interromperia a execucao.

## 7. Como funciona o controle negativo

O argumento `+NEGATIVE_EXPECTATION` seleciona outra execucao do mesmo
testbench. O log identifica essa fase como `phase=negative_expectation`.
Ela parte de reset, chega legalmente a `Run-Test/Idle` e muda
**uma unica entrada da tabela do modelo**:

```systemverilog
next_expected[IDLE][0] = SEL_DR;
```

Essa entrada esta errada de proposito. Com TMS=0, o RTL correto deve
permanecer em Idle (`state_o = 4'hC`), enquanto a referencia adulterada
espera `Select-DR-Scan` (`4'h7`). Na comparacao depois da subida, o log
mostra `STATE_MISMATCH`, emite `NEGATIVE_EXPECTATION_DETECTED` e chama
`$fatal`. Se o comparador deixar esse erro passar, a linha
`NEGATIVE_NOT_DETECTED` faz a execucao falhar.

O `Fatal` dessa fase e **resultado esperado**: prova que o testbench
rejeita aquela expectativa falsa. Ele nao representa um defeito demonstrado
na FSM. O roteiro `scripts/run_vcs.sh` aceita o negativo somente quando
encontra a divergencia exata, o marcador especifico e a mensagem do
`$fatal`. O codigo de saida do VCS pode variar entre configuracoes; por
isso, o roteiro valida o conteudo do log e rejeita um marcador positivo
indevido no negativo.

## 8. Como ler os contadores do positivo

Na execucao, a linha final foi:

```text
TAP_POSITIVE_PASS transitions=32/32 reset_cases=16/16 async_reset_cases=16/16 cycles=747 state_checks=1528 indicator_bit_checks=10696 stability_samples=747
```

- `transitions=32/32`: todos os 16 estados foram testados com os dois TMS.
- `reset_cases=16/16`: a recuperacao por cinco TMS=1 passou nas 16 origens.
- `async_reset_cases=16/16`: o pulso de `trst_n` passou nas 16 origens.
- `cycles=747`: chamadas completas a `jtag_cycle`, com `TRACE` e hit de
  cobertura. Nao e o numero total de bordas de TCK durante a simulacao.
- `state_checks=1528`: duas comparacoes por ciclo registrado (antes e depois
  da subida), mais 34 comparacoes feitas pelos 17 pulsos de `trst_n`:
  `2 x 747 + 2 x (1 inicial + 16 de campanha) = 1528`.
- `indicator_bit_checks=10696`: sete indicadores por comparacao de estado:
  `7 x 1528 = 10696`.
- `stability_samples=747`: uma amostra antes da subida por `jtag_cycle`.

Ha bordas de TCK nao registradas por `jtag_cycle` ao redor de alguns pulsos
de `trst_n`; nesse intervalo TMS esta em 1 e a referencia/RTL permanecem em
reset. Por isso podem aparecer intervalos de 40 ns entre duas linhas TRACE.
Isso nao reduz a cobertura informada dos 32 pares, mas evita interpretar
`cycles` como todas as bordas de relogio.

## 9. Mensagens do VCS

- `Warning-[RT-NCMUCS]` em `time 0ps`: o estado ainda esta indefinido antes
  do primeiro pulso de reset do testbench. O aviso nao reapareceu apos o reset.
- `VCS_SAVE_RESTORE_INFO` sobre ASLR: mensagem informativa do simulador.
- `$finish` no positivo: encerramento normal apos `TAP_POSITIVE_PASS`.
- `Fatal` no negativo: encerramento intencional apos o erro provocado.
- `TAP_REGRESSION_PASS`: mensagem do roteiro externo confirmando que o
  positivo foi aceito e o negativo foi rejeitado pela causa prevista.

## 10. Reproducao da simulacao

Na pasta `Tap_FSM` do servidor do laboratorio:

```bash
source /Tools/synopsys-scripts/snps.sh
bash scripts/run_vcs.sh
```

O roteiro cria `logs/verification_*/` com configuracao, compilacao, log
positivo, log negativo e resumo. Na execucao de 15/10/2026, o
resumo exibiu `TAP_REGRESSION_PASS positive=accepted
negative=rejected_as_expected` e apontou para
`logs/verification_20261015_213518_TNQE5m`.
