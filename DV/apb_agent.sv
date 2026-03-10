// ============================================================
// APB UVM Agent
// Instantiates driver, monitor, sequencer
// Supports ACTIVE (drives + monitors) and PASSIVE (monitor only)
// ============================================================

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    // Sub-components
    apb_driver     driver;
    apb_monitor    monitor;
    apb_sequencer  sequencer;

    // Analysis port (forwarded from monitor)
    uvm_analysis_port #(apb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------
    // build_phase
    // ----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Monitor always created
        monitor = apb_monitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            driver    = apb_driver::type_id::create("driver",    this);
            sequencer = apb_sequencer::type_id::create("sequencer", this);
        end

        // Create analysis port
        ap = new("ap", this);
    endfunction

    // ----------------------------------------------------------
    // connect_phase
    // ----------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Connect driver to sequencer
        if (is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);

        // Forward monitor analysis port
        monitor.ap.connect(ap);
    endfunction

endclass
