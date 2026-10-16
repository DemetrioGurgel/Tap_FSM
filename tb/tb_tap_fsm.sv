`timescale 1ns/1ps

// Modelo independente: IDs, tabela e caminhos nao sao importados do RTL.
// Fonte: IEEE 1149.1-2001, Figura 6-1 e regra 6.1.1 b).
// state_o e usado APENAS como resposta observada, nunca como expectativa.
module tb_tap_fsm;
  localparam int TLR=0, IDLE=1, SEL_DR=2, CAP_DR=3, SH_DR=4,
                 EX1_DR=5, PA_DR=6, EX2_DR=7, UP_DR=8,
                 SEL_IR=9, CAP_IR=10, SH_IR=11, EX1_IR=12,
                 PA_IR=13, EX2_IR=14, UP_IR=15;

  logic tck = 0;
  logic trst_n = 1;
  logic tms = 1;
  wire [3:0] state_o;
  wire test_logic_reset, capture_dr, shift_dr, update_dr;
  wire capture_ir, shift_ir, update_ir;

  tap_fsm dut (.*);
  always #10 tck = ~tck;

  int next_expected [0:15][0:1];
  int transition_hits [0:15][0:1];
  logic [3:0] observed_code [0:15];
  string state_name [0:15];
  string reset_path [0:15];
  int expected_state = TLR;
  int state_checks = 0;
  int indicator_checks = 0;
  int stability_checks = 0;
  int cycles = 0;
  int recovery_cases = 0;
  int async_reset_cases = 0;
  bit negative_mode;
  bit negative_armed = 0;
  string phase = "initialization";

  task automatic initialize_reference;
    // Colunas: TMS=0 e TMS=1. Transcricao da figura normativa.
    next_expected[TLR][0]=IDLE;      next_expected[TLR][1]=TLR;
    next_expected[IDLE][0]=IDLE;     next_expected[IDLE][1]=SEL_DR;
    next_expected[SEL_DR][0]=CAP_DR; next_expected[SEL_DR][1]=SEL_IR;
    next_expected[CAP_DR][0]=SH_DR;  next_expected[CAP_DR][1]=EX1_DR;
    next_expected[SH_DR][0]=SH_DR;   next_expected[SH_DR][1]=EX1_DR;
    next_expected[EX1_DR][0]=PA_DR;  next_expected[EX1_DR][1]=UP_DR;
    next_expected[PA_DR][0]=PA_DR;   next_expected[PA_DR][1]=EX2_DR;
    next_expected[EX2_DR][0]=SH_DR;  next_expected[EX2_DR][1]=UP_DR;
    next_expected[UP_DR][0]=IDLE;    next_expected[UP_DR][1]=SEL_DR;
    next_expected[SEL_IR][0]=CAP_IR; next_expected[SEL_IR][1]=TLR;
    next_expected[CAP_IR][0]=SH_IR;  next_expected[CAP_IR][1]=EX1_IR;
    next_expected[SH_IR][0]=SH_IR;   next_expected[SH_IR][1]=EX1_IR;
    next_expected[EX1_IR][0]=PA_IR;  next_expected[EX1_IR][1]=UP_IR;
    next_expected[PA_IR][0]=PA_IR;   next_expected[PA_IR][1]=EX2_IR;
    next_expected[EX2_IR][0]=SH_IR;  next_expected[EX2_IR][1]=UP_IR;
    next_expected[UP_IR][0]=IDLE;    next_expected[UP_IR][1]=SEL_DR;

    // Adaptador de observacao: codificacao publicada na interface deste RTL.
    // Estes valores nao determinam as transicoes do modelo.
    observed_code[TLR]=4'hf;    state_name[TLR]="Test-Logic-Reset"; reset_path[TLR]="";
    observed_code[IDLE]=4'hc;   state_name[IDLE]="Run-Test/Idle";   reset_path[IDLE]="0";
    observed_code[SEL_DR]=4'h7; state_name[SEL_DR]="Select-DR-Scan"; reset_path[SEL_DR]="01";
    observed_code[CAP_DR]=4'h6; state_name[CAP_DR]="Capture-DR";     reset_path[CAP_DR]="010";
    observed_code[SH_DR]=4'h2;  state_name[SH_DR]="Shift-DR";       reset_path[SH_DR]="0100";
    observed_code[EX1_DR]=4'h1; state_name[EX1_DR]="Exit1-DR";       reset_path[EX1_DR]="0101";
    observed_code[PA_DR]=4'h3;  state_name[PA_DR]="Pause-DR";       reset_path[PA_DR]="01010";
    observed_code[EX2_DR]=4'h0; state_name[EX2_DR]="Exit2-DR";       reset_path[EX2_DR]="010101";
    observed_code[UP_DR]=4'h5;  state_name[UP_DR]="Update-DR";      reset_path[UP_DR]="01011";
    observed_code[SEL_IR]=4'h4; state_name[SEL_IR]="Select-IR-Scan"; reset_path[SEL_IR]="011";
    observed_code[CAP_IR]=4'he; state_name[CAP_IR]="Capture-IR";     reset_path[CAP_IR]="0110";
    observed_code[SH_IR]=4'ha;  state_name[SH_IR]="Shift-IR";       reset_path[SH_IR]="01100";
    observed_code[EX1_IR]=4'h9; state_name[EX1_IR]="Exit1-IR";       reset_path[EX1_IR]="01101";
    observed_code[PA_IR]=4'hb;  state_name[PA_IR]="Pause-IR";       reset_path[PA_IR]="011010";
    observed_code[EX2_IR]=4'h8; state_name[EX2_IR]="Exit2-IR";       reset_path[EX2_IR]="0110101";
    observed_code[UP_IR]=4'hd;  state_name[UP_IR]="Update-IR";      reset_path[UP_IR]="011011";
    for (int s=0; s<16; s++)
      for (int b=0; b<2; b++) transition_hits[s][b]=0;
  endtask

  task automatic check_observation(input string point);
    logic [6:0] expected_flags;
    logic [6:0] actual_flags;
    state_checks++;
    if (state_o !== observed_code[expected_state]) begin
      $display("STATE_MISMATCH time=%0t phase=%s point=%s expected=%s code=%h actual=%h",
               $time, phase, point, state_name[expected_state],
               observed_code[expected_state], state_o);
      // Apenas o erro provocado, no ponto exato, recebe este marcador.
      if (negative_armed && point == "after_rising_edge" &&
          expected_state == SEL_DR && state_o === observed_code[IDLE]) begin
        $display("NEGATIVE_EXPECTATION_DETECTED mutated=Run-Test/Idle,TMS=0 expected=Select-DR-Scan actual=Run-Test/Idle");
        $fatal(1, "Intentional reference-table mismatch detected");
      end
      $fatal(1, "TAP_UNEXPECTED_STATE_ERROR");
    end
    expected_flags = {expected_state==TLR, expected_state==CAP_DR,
                      expected_state==SH_DR, expected_state==UP_DR,
                      expected_state==CAP_IR, expected_state==SH_IR,
                      expected_state==UP_IR};
    actual_flags = {test_logic_reset, capture_dr, shift_dr, update_dr,
                    capture_ir, shift_ir, update_ir};
    indicator_checks += 7;
    if (actual_flags !== expected_flags)
      $fatal(1, "TAP_INDICATOR_ERROR time=%0t phase=%s point=%s expected=%b actual=%b",
             $time, phase, point, expected_flags, actual_flags);
  endtask

  // Mestre: muda TMS na descida e compara 1 ns apos a subida (apos NBA).
  // TDI nao existe nesta interface: este ensaio nao transfere dados seriais.
  task automatic jtag_cycle(input bit tms_value);
    int previous_state;
    previous_state = expected_state;
    @(negedge tck);
    tms = tms_value;
    #1;
    check_observation("before_rising_edge");
    stability_checks++;
    @(posedge tck);
    expected_state = next_expected[previous_state][tms_value];
    #1;
    check_observation("after_rising_edge");
    transition_hits[previous_state][tms_value]++;
    cycles++;
    $display("TRACE cycle=%0d time=%0t phase=%s from=%s TMS=%0b expected=%s observed=%h",
             cycles, $time, phase, state_name[previous_state], tms_value,
             state_name[expected_state], state_o);
  endtask

  task automatic send_sequence(input string sequence_bits);
    for (int i=0; i<sequence_bits.len(); i++) begin
      if (sequence_bits.getc(i) != 8'h30 && sequence_bits.getc(i) != 8'h31)
        $fatal(1, "Invalid TMS sequence");
      jtag_cycle(sequence_bits.getc(i) == 8'h31);
    end
  endtask

  task automatic reset_by_tms;
    repeat (5) jtag_cycle(1);
    if (expected_state != TLR || state_o !== observed_code[TLR])
      $fatal(1, "TAP_TMS_RESET_ERROR");
  endtask

  task automatic reach_state(input int target);
    reset_by_tms();
    send_sequence(reset_path[target]);
    if (expected_state != target)
      $fatal(1, "Invalid reference path for %s", state_name[target]);
  endtask

  // Teste adicional da porta fornecida pelo RTL: assertar fora da subida.
  task automatic pulse_trst;
    #2;
    trst_n = 0;
    expected_state = TLR;
    #1;
    check_observation("async_reset_asserted");
    @(negedge tck);
    tms = 1;
    #1;
    trst_n = 1;
    #1;
    check_observation("async_reset_released");
  endtask

  initial begin : campaign
    int covered;
    $timeformat(-9, 0, " ns", 10);
    negative_mode = $test$plusargs("NEGATIVE_EXPECTATION");
    initialize_reference();
    $display("TAP_RUN mode=%s TCK_PERIOD_NS=20 SAMPLE_DELAY_NS=1",
             negative_mode ? "negative" : "positive");
    if ($test$plusargs("DUMP_VCD")) begin
      $dumpfile("work/tap_fsm.vcd");
      $dumpvars(0, tb_tap_fsm);
    end
    pulse_trst();

    if (negative_mode) begin
      phase = "negative_expectation";
      reach_state(IDLE);
      // Altera UMA expectativa, sem alterar o DUT ou a resposta observada.
      next_expected[IDLE][0] = SEL_DR;
      negative_armed = 1;
      jtag_cycle(0);
      $fatal(1, "NEGATIVE_NOT_DETECTED");
    end else begin
      phase = "all_transitions";
      for (int s=0; s<16; s++) begin
        for (int b=0; b<2; b++) begin
          reach_state(s);
          jtag_cycle(b == 1);
        end
      end

      phase = "reset_recovery";
      for (int s=0; s<16; s++) begin
        reach_state(s);
        reset_by_tms();
        recovery_cases++;
        $display("RESET_RECOVERY from=%s result=OK", state_name[s]);
      end

      phase = "idle_hold";
      reach_state(IDLE);
      repeat (10) jtag_cycle(0);

      phase = "dr_pause_resume";
      reset_by_tms();
      send_sequence("010010100110");
      if (expected_state != IDLE) $fatal(1, "DR path did not end in Idle");

      phase = "ir_pause_resume";
      reset_by_tms();
      send_sequence("0110010100110");
      if (expected_state != IDLE) $fatal(1, "IR path did not end in Idle");

      phase = "async_reset";
      for (int s=0; s<16; s++) begin
        reach_state(s);
        pulse_trst();
        async_reset_cases++;
        $display("ASYNC_RESET from=%s result=OK", state_name[s]);
      end

      covered=0;
      for (int s=0; s<16; s++) begin
        for (int b=0; b<2; b++) begin
          $display("COVERAGE from=%s TMS=%0d to=%s hits=%0d",
                   state_name[s], b, state_name[next_expected[s][b]], transition_hits[s][b]);
          if (transition_hits[s][b]>0) covered++;
        end
      end
      if (covered!=32 || recovery_cases!=16 || async_reset_cases!=16)
        $fatal(1, "TAP_INCOMPLETE_CAMPAIGN");
      $display("TAP_POSITIVE_PASS transitions=%0d/32 reset_cases=%0d/16 async_reset_cases=%0d/16 cycles=%0d state_checks=%0d indicator_bit_checks=%0d stability_samples=%0d",
               covered, recovery_cases, async_reset_cases, cycles,
               state_checks, indicator_checks, stability_checks);
      $finish;
    end
  end

  initial begin
    #100000;
    $fatal(1, "TAP_TIMEOUT");
  end
endmodule
