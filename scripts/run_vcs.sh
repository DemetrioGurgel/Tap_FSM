#!/usr/bin/env bash
# Executar com: bash scripts/run_vcs.sh (apos carregar o ambiente Synopsys).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v vcs >/dev/null || { echo 'VCS indisponivel. Carregue o ambiente Synopsys.' >&2; exit 1; }
mkdir -p work/vcs logs
# Pasta distinta por execucao: preserva tentativas e negativos anteriores.
run_dir=$(mktemp -d "logs/verification_$(date +%Y%m%d_%H%M%S)_XXXXXX")
printf 'Logs desta execucao: %s\n' "$run_dir"
{
  date -Is
  command -v vcs
  printf 'Top: tb_tap_fsm; TCK: 20 ns; amostragem: subida + 1 ns\n'
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git rev-parse HEAD
    git status --short
  else
    printf 'Copia sem metadados Git; identificar fontes pelos hashes abaixo.\n'
  fi
  sha256sum rtl/tap_state_pkg.sv rtl/tap_fsm.sv tb/tb_tap_fsm.sv scripts/run_vcs.sh
} > "$run_dir/configuration.log"

vcs -full64 -sverilog -timescale=1ns/1ps \
  rtl/tap_state_pkg.sv rtl/tap_fsm.sv tb/tb_tap_fsm.sv \
  -top tb_tap_fsm -Mdir=work/vcs/csrc_tb -o work/vcs/simv_tb \
  2>&1 | tee "$run_dir/compile.log"

work/vcs/simv_tb 2>&1 | tee "$run_dir/positive.log"
grep -q '^TAP_POSITIVE_PASS transitions=32/32 reset_cases=16/16 async_reset_cases=16/16 ' "$run_dir/positive.log"
if grep -Eq 'STATE_MISMATCH|TAP_.*ERROR|NEGATIVE_|Error-|Fatal|FATAL' "$run_dir/positive.log"; then
  echo 'Resultado positivo contem erro inesperado.' >&2
  exit 1
fi

# Algumas configuracoes do VCS encerram com status 0 mesmo apos $fatal.
# Aceitar apenas a assinatura completa da divergencia intencional.
set +e
work/vcs/simv_tb +NEGATIVE_EXPECTATION 2>&1 | tee "$run_dir/negative.log"
negative_statuses=("${PIPESTATUS[@]}")
set -e
printf 'VCS negative exit status: %s; tee exit status: %s\n' \
  "${negative_statuses[0]}" "${negative_statuses[1]}" >> "$run_dir/configuration.log"
if [[ ${negative_statuses[1]} -ne 0 ]] ||
   ! grep -q '^STATE_MISMATCH .*phase=negative_expectation point=after_rising_edge expected=Select-DR-Scan code=7 actual=c' "$run_dir/negative.log" ||
   ! grep -q '^NEGATIVE_EXPECTATION_DETECTED mutated=Run-Test/Idle,TMS=0 expected=Select-DR-Scan actual=Run-Test/Idle$' "$run_dir/negative.log" ||
   ! grep -q 'Intentional reference-table mismatch detected' "$run_dir/negative.log" ||
   grep -Eq 'TAP_POSITIVE_PASS|NEGATIVE_NOT_DETECTED|TAP_UNEXPECTED_STATE_ERROR|TAP_INDICATOR_ERROR|TAP_TIMEOUT' "$run_dir/negative.log"; then
  echo 'Controle negativo nao produziu a rejeicao esperada.' >&2
  exit 1
fi
printf 'TAP_REGRESSION_PASS positive=accepted negative=rejected_as_expected logs=%s\n' "$run_dir" | tee "$run_dir/summary.log"
