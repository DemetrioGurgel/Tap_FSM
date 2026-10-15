// =============================================================================
// Arquivo   : tap_state_pkg.sv
// Projeto   : Trilha DFT - Fase 2 - Grupo 2 (JTAG)
// Descricao : Estados do controlador TAP, com a codificacao da Tabela 6-3
//             da IEEE 1149.1-2001 (state assignments for example TAP
//             controller).
// =============================================================================

package tap_state_pkg;

  typedef enum logic [3:0] {
    EXIT2_DR         = 4'h0,
    EXIT1_DR         = 4'h1,
    SHIFT_DR         = 4'h2,
    PAUSE_DR         = 4'h3,
    SELECT_IR_SCAN   = 4'h4,
    UPDATE_DR        = 4'h5,
    CAPTURE_DR       = 4'h6,
    SELECT_DR_SCAN   = 4'h7,
    EXIT2_IR         = 4'h8,
    EXIT1_IR         = 4'h9,
    SHIFT_IR         = 4'hA,
    PAUSE_IR         = 4'hB,
    RUN_TEST_IDLE    = 4'hC,
    UPDATE_IR        = 4'hD,
    CAPTURE_IR       = 4'hE,
    TEST_LOGIC_RESET = 4'hF
  } tap_state_t;

endpackage : tap_state_pkg
