# =============================================================================
# DBPU - Dynamic Branch Prediction Unit : build / test / analysis flow
# Run every target from the repository root.
#
#   make test        compile + run all self-checking testbenches
#   make sim TB=tb_two_bit_predictor        run one testbench
#   make wave TB=tb_two_bit_predictor       run one testbench + open GTKWave
#   make traces      regenerate the branch traces (deterministic)
#   make programs    assemble programs/*.s and compute reference results (ISS)
#   make cpu         run all programs on the 5-stage RV32I CPU + CPI analysis
#   make results     trace sims + BHT sweep + pipelined runs + analysis/plots
#   make waves       render waveform PNGs from the VCD files (matplotlib)
#   make synth       Yosys synthesis of all three predictor configurations
#   make report      build reports/IEEE_Project_Report.pdf (tectonic)
#   make all         test + results + waves + synth
#   make clean       remove build products
# =============================================================================
IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3
YOSYS    ?= yosys
TECTONIC ?= tectonic

RTL      := $(wildcard rtl/*.v)
TRACES   := loop_trace alternating_trace mostly_taken mostly_not_taken mixed_trace aliasing_trace
SWEEP_TRACES := mixed_trace aliasing_trace
SWEEP_SIZES  := 2 4 8 16 32 64
RES      := analysis/results

.PHONY: all test sim wave traces programs cpu sim-traces sweep pipeline analysis results waves synth report clean

all: test results waves synth

test:
	bash simulation/run_tests.sh

sim:
	bash simulation/run_sim.sh $(TB)

wave:
	bash simulation/run_sim.sh $(TB) --wave

traces:
	$(PYTHON) traces/generate_traces.py

programs:
	$(PYTHON) scripts/build_programs.py

# Phase II: run every program on the pipeline with each predictor, then analyse
cpu: programs
	@mkdir -p build $(RES)
	$(IVERILOG) -g2005 -Wall -o build/tb_rv32_pipeline testbench/tb_rv32_pipeline.v $(RTL)
	$(VVP) -n build/tb_rv32_pipeline +OUT=$(RES)/cpu_results.csv
	$(PYTHON) analysis/cpu_analysis.py

build/tb_trace_runner: testbench/tb_trace_runner.v $(RTL)
	@mkdir -p build
	$(IVERILOG) -g2005 -Wall -o $@ testbench/tb_trace_runner.v $(RTL)

build/tb_branch_prediction_top: testbench/tb_branch_prediction_top.v $(RTL)
	@mkdir -p build
	$(IVERILOG) -g2005 -Wall -o $@ testbench/tb_branch_prediction_top.v $(RTL)

# Accuracy study: identical trace fed to static / 1-bit / 2-bit (BHT = 16)
sim-traces: build/tb_trace_runner
	@mkdir -p $(RES)
	@for t in $(TRACES); do \
	  $(VVP) -n build/tb_trace_runner +TRACE=traces/$$t.csv +OUT=$(RES)/sim_$$t.csv | grep TRACE_SUMMARY; \
	done
	$(VVP) -n build/tb_trace_runner +TRACE=traces/loop_trace.csv +OUT=build/loop_dump.csv +DUMP > /dev/null

# BHT size sweep: RTL recompiled for each size
sweep:
	@mkdir -p $(RES)/sweep build
	@for n in $(SWEEP_SIZES); do \
	  $(IVERILOG) -g2005 -o build/tr_bht$$n -Ptb_trace_runner.BHT_ENTRIES=$$n testbench/tb_trace_runner.v $(RTL) || exit 1; \
	  for t in $(SWEEP_TRACES); do \
	    $(VVP) -n build/tr_bht$$n +TRACE=traces/$$t.csv +OUT=$(RES)/sweep/sim_$${t}_bht$$n.csv | grep TRACE_SUMMARY; \
	  done; \
	done

# Pipelined timing (delayed update + squash), self-checking, per trace
pipeline: build/tb_branch_prediction_top
	@mkdir -p $(RES)
	@: > $(RES)/pipeline_summary.txt
	@for t in $(TRACES); do \
	  echo "TRACE $$t" >> $(RES)/pipeline_summary.txt; \
	  $(VVP) -n build/tb_branch_prediction_top +TRACE=traces/$$t.csv | grep -E "SUMMARY|TEST_RESULT" >> $(RES)/pipeline_summary.txt; \
	done
	@cat $(RES)/pipeline_summary.txt
	@! grep -q "TEST_RESULT: FAIL" $(RES)/pipeline_summary.txt

analysis:
	$(PYTHON) analysis/performance_analysis.py

results: sim-traces sweep pipeline analysis cpu

waves: test sim-traces
	$(PYTHON) scripts/vcd_to_png.py

synth:
	bash synthesis/run_synth.sh

report:
	cd reports && $(TECTONIC) IEEE_Project_Report.tex

clean:
	rm -rf build programs/build simulation/logs simulation/waveforms/*.vcd
