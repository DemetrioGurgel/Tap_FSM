// =============================================================================
// Arquivo   : tap_fsm.sv
// Projeto   : Trilha DFT - Fase 2 - Grupo 2 (JTAG)
// Descricao : Controlador TAP de 16 estados, conforme IEEE 1149.1-2001,
//             secao 6 (diagrama de estados na Figura 6-1).
//
// Convencoes do modulo de estudo:
//   - trst_n : reset assincrono ativo baixo (TRST*, regra 6.3.1 c).
//   - state_o: estado atual, exposto apenas para verificacao.
// =============================================================================

module tap_fsm
  import tap_state_pkg::*;
(
  input  logic       tck,              // relogio de teste
  input  logic       trst_n,           // reset assincrono, ativo baixo
  input  logic       tms,              // amostrado na borda de subida de TCK

  // Indicadores: nivel alto enquanto a FSM esta no estado correspondente
  output logic       test_logic_reset,
  output logic       capture_dr,
  output logic       shift_dr,
  output logic       update_dr,
  output logic       capture_ir,
  output logic       shift_ir,
  output logic       update_ir,

  output tap_state_t state_o           // diagnostico (modulo de estudo)
);

  tap_state_t state, next_state;

  // Registrador de estado: transicoes na subida de TCK (regra 6.1.1 b);
  // TRST* leva a Test-Logic-Reset de forma assincrona (regra 6.3.1 c).
  always_ff @(posedge tck or negedge trst_n) begin
    if (!trst_n) state <= TEST_LOGIC_RESET;
    else         state <= next_state;
  end

  // Logica de proximo estado (Figura 6-1): tms ? destino_1 : destino_0.
  // O valor padrao evita latch; os 16 codigos estao cobertos, sem default.
  always_comb begin
    next_state = state;
    unique case (state)
      TEST_LOGIC_RESET: next_state = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
      RUN_TEST_IDLE:    next_state = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;

      // Ramo DR
      SELECT_DR_SCAN:   next_state = tms ? SELECT_IR_SCAN   : CAPTURE_DR;
      CAPTURE_DR:       next_state = tms ? EXIT1_DR         : SHIFT_DR;
      SHIFT_DR:         next_state = tms ? EXIT1_DR         : SHIFT_DR;
      EXIT1_DR:         next_state = tms ? UPDATE_DR        : PAUSE_DR;
      PAUSE_DR:         next_state = tms ? EXIT2_DR         : PAUSE_DR;
      EXIT2_DR:         next_state = tms ? UPDATE_DR        : SHIFT_DR;
      UPDATE_DR:        next_state = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;

      // Ramo IR
      SELECT_IR_SCAN:   next_state = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
      CAPTURE_IR:       next_state = tms ? EXIT1_IR         : SHIFT_IR;
      SHIFT_IR:         next_state = tms ? EXIT1_IR         : SHIFT_IR;
      EXIT1_IR:         next_state = tms ? UPDATE_IR        : PAUSE_IR;
      PAUSE_IR:         next_state = tms ? EXIT2_IR         : PAUSE_IR;
      EXIT2_IR:         next_state = tms ? UPDATE_IR        : SHIFT_IR;
      UPDATE_IR:        next_state = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;
    endcase
  end

  // Saidas (Moore): dependem apenas do estado registrado e ficam estaveis
  // entre duas bordas de subida de TCK.
  assign test_logic_reset = (state == TEST_LOGIC_RESET);
  assign capture_dr       = (state == CAPTURE_DR);
  assign shift_dr         = (state == SHIFT_DR);
  assign update_dr        = (state == UPDATE_DR);
  assign capture_ir       = (state == CAPTURE_IR);
  assign shift_ir         = (state == SHIFT_IR);
  assign update_ir        = (state == UPDATE_IR);
  assign state_o          = state;

endmodule : tap_fsm
