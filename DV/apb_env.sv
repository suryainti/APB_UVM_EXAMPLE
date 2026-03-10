// ============================================================
// APB UVM Environment
// Instantiates and connects: Agent, Scoreboard, Coverage
// ============================================================

class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    // Sub-components
    apb_agent      agent;
    apb_scoreboard scoreboard;
    apb_coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------
    // build_phase
    // ----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = apb_agent::type_id::create("agent",      this);
        scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
        coverage   = apb_coverage::type_id::create("coverage",   this);

        // Configure agent as ACTIVE
        uvm_config_db #(uvm_active_passive_enum)::set(
            this, "agent", "is_active", UVM_ACTIVE);
    endfunction

    // ----------------------------------------------------------
    // connect_phase: Connect monitor to scoreboard and coverage
    // ----------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Monitor -> Scoreboard
        agent.ap.connect(scoreboard.analysis_export);

        // Monitor -> Coverage
        agent.ap.connect(coverage.analysis_export);
    endfunction

endclass
