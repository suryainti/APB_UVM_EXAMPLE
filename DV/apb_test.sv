// ============================================================
// APB UVM Tests
// ============================================================

// ------------------------------------------------------------
// Base Test
// ------------------------------------------------------------
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        // Print topology
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Base test run - override in child", UVM_MEDIUM)
    endtask
endclass

// ------------------------------------------------------------
// Smoke Test - Basic write/read
// ------------------------------------------------------------
class apb_smoke_test extends apb_base_test;
    `uvm_component_utils(apb_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq  wr_seq;
        apb_read_seq   rd_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== SMOKE TEST STARTED ===", UVM_MEDIUM)

        // Single write
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 32'h0000_0000;
        wr_seq.wr_data = 32'hDEAD_BEEF;
        wr_seq.wr_strb = 4'hF;
        wr_seq.start(env.agent.sequencer);

        // Read back
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.rd_addr = 32'h0000_0000;
        rd_seq.start(env.agent.sequencer);

        #100;
        `uvm_info(get_type_name(), "=== SMOKE TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ------------------------------------------------------------
// Write-Read Test - Write then read back all locations
// ------------------------------------------------------------
class apb_wr_rd_test extends apb_base_test;
    `uvm_component_utils(apb_wr_rd_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_wr_rd_seq seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== WRITE-READ TEST STARTED ===", UVM_MEDIUM)

        seq = apb_wr_rd_seq::type_id::create("seq");
        seq.num_txns = 16;
        seq.start(env.agent.sequencer);

        #100;
        `uvm_info(get_type_name(), "=== WRITE-READ TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ------------------------------------------------------------
// Random Test - Randomized transactions
// ------------------------------------------------------------
class apb_rand_test extends apb_base_test;
    `uvm_component_utils(apb_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_rand_seq seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== RANDOM TEST STARTED ===", UVM_MEDIUM)

        seq = apb_rand_seq::type_id::create("seq");
        seq.num_txns = 100;
        seq.start(env.agent.sequencer);

        #100;
        `uvm_info(get_type_name(), "=== RANDOM TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ------------------------------------------------------------
// Burst Test - Sequential burst write
// ------------------------------------------------------------
class apb_burst_test extends apb_base_test;
    `uvm_component_utils(apb_burst_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_burst_write_seq burst_seq;
        apb_read_seq        rd_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== BURST TEST STARTED ===", UVM_MEDIUM)

        // Burst write
        burst_seq = apb_burst_write_seq::type_id::create("burst_seq");
        burst_seq.start_addr = 32'h0000_0000;
        burst_seq.burst_len  = 16;
        burst_seq.start(env.agent.sequencer);

        // Read all back
        for (int i = 0; i < 16; i++) begin
            rd_seq = apb_read_seq::type_id::create("rd_seq");
            rd_seq.rd_addr = i * 4;
            rd_seq.start(env.agent.sequencer);
        end

        #100;
        `uvm_info(get_type_name(), "=== BURST TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ------------------------------------------------------------
// Error Test - PSLVERR injection
// ------------------------------------------------------------
class apb_error_test extends apb_base_test;
    `uvm_component_utils(apb_error_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_error_seq  err_seq;
        apb_rand_seq   norm_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== ERROR TEST STARTED ===", UVM_MEDIUM)

        // Normal transactions first
        norm_seq = apb_rand_seq::type_id::create("norm_seq");
        norm_seq.num_txns = 10;
        norm_seq.start(env.agent.sequencer);

        // Inject error
        err_seq = apb_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.sequencer);

        // Normal transactions after error
        norm_seq = apb_rand_seq::type_id::create("norm_seq2");
        norm_seq.num_txns = 10;
        norm_seq.start(env.agent.sequencer);

        #100;
        `uvm_info(get_type_name(), "=== ERROR TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

// ------------------------------------------------------------
// Full Regression Test - All scenarios
// ------------------------------------------------------------
class apb_full_test extends apb_base_test;
    `uvm_component_utils(apb_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq      wr_seq;
        apb_read_seq       rd_seq;
        apb_wr_rd_seq      wr_rd_seq;
        apb_burst_write_seq burst_seq;
        apb_rand_seq       rand_seq;
        apb_error_seq      err_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "=== FULL REGRESSION TEST STARTED ===", UVM_MEDIUM)

        // 1. Smoke: write/read word 0
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 32'h0; wr_seq.wr_data = 32'hA5A5_A5A5; wr_seq.wr_strb = 4'hF;
        wr_seq.start(env.agent.sequencer);
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.rd_addr = 32'h0;
        rd_seq.start(env.agent.sequencer);

        // 2. Burst write all registers
        burst_seq = apb_burst_write_seq::type_id::create("burst_seq");
        burst_seq.start_addr = 32'h0; burst_seq.burst_len = 16;
        burst_seq.start(env.agent.sequencer);

        // 3. Write-then-read back
        wr_rd_seq = apb_wr_rd_seq::type_id::create("wr_rd_seq");
        wr_rd_seq.num_txns = 16;
        wr_rd_seq.start(env.agent.sequencer);

        // 4. Random stress
        rand_seq = apb_rand_seq::type_id::create("rand_seq");
        rand_seq.num_txns = 200;
        rand_seq.start(env.agent.sequencer);

        // 5. Error injection
        err_seq = apb_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.sequencer);

        #100;
        `uvm_info(get_type_name(), "=== FULL REGRESSION TEST COMPLETE ===", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass
