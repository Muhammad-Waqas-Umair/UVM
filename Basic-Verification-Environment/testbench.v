`include "uvm_macros.svh"
import uvm_pkg::*;

// ---------------------- SEQUENCE ITEM -------------------------
class Sequence_Item extends uvm_sequence_item;
    rand bit reset;
    rand bit data_in;
    bit data_out;

    `uvm_object_utils_begin(Sequence_Item)
        `uvm_field_int(reset,    UVM_DEFAULT)
        `uvm_field_int(data_in,  UVM_DEFAULT)
        `uvm_field_int(data_out, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "sequence_item");
        super.new(name);
    endfunction
endclass

// ---------------------- SEQUENCE -------------------------
class Inactive_Reset_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Inactive_Reset_Seq)

    function new(string Name = "Inactive_Reset_Seq");
        super.new(Name);
    endfunction

    virtual task body();
        Sequence_Item obj = Sequence_Item::type_id::create("obj");
        repeat(4) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b0;
            `uvm_info(get_type_name(), "Driver sending data with reset inactive", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass

class Active_Reset_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Active_Reset_Seq)

    function new(string Name = "Active_Reset_Seq");
        super.new(Name);
    endfunction

    virtual task body();
        Sequence_Item obj = Sequence_Item::type_id::create("obj");
        repeat(4) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b1;
            `uvm_info(get_type_name(), "Driver sending data with active reset", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass

class Random_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Random_Seq)

    function new(string Name = "Random_Seq");
        super.new(Name);
    endfunction

    virtual task body();
        Sequence_Item obj = Sequence_Item::type_id::create("obj");
        repeat(4) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b0;
            `uvm_info(get_type_name(), "Driver sending randomized data", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass

// ---------------------- SEQUENCER -------------------------
class My_Sequencer extends uvm_sequencer #(Sequence_Item);
    `uvm_component_utils(My_Sequencer)

    function new(string Name = "My_Sequencer", uvm_component parent = null);
        super.new(Name, parent);
    endfunction
endclass

// ---------------------- DRIVER -------------------------
class My_Driver extends uvm_driver #(Sequence_Item);
    `uvm_component_utils(My_Driver)

    virtual dff_interface vif;
    Sequence_Item obj;

    function new(string Name = "My_Driver", uvm_component parent = null);
        super.new(Name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        obj = Sequence_Item::type_id::create("obj");
        if (!uvm_config_db#(virtual dff_interface)::get(this, "", "Virtual Interface", vif))
            `uvm_fatal(get_type_name(), "Virtual interface not set")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(obj);
            vif.reset   <= obj.reset;
            vif.data_in <= obj.data_in;
            `uvm_info(get_type_name(), "Data sent to DUT", UVM_NONE)
            obj.print();
            seq_item_port.item_done();
            repeat(3) @(posedge vif.clock);
        end
    endtask
endclass

// ---------------------- MONITOR -------------------------
class My_Monitor extends uvm_monitor;
    `uvm_component_utils(My_Monitor)

    Sequence_Item obj;
    virtual dff_interface vif;
    uvm_analysis_port #(Sequence_Item) Aobj;

    function new(string Name = "My_Monitor", uvm_component parent = null);
        super.new(Name, parent);
        Aobj = new("Aobj", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        obj = Sequence_Item::type_id::create("obj", this);
        if (!uvm_config_db#(virtual dff_interface)::get(this, "", "Virtual Interface", vif))
            `uvm_fatal(get_type_name(), "Unable to access the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            repeat(3) @(posedge vif.clock);
            obj.reset    = vif.reset;
            obj.data_in  = vif.data_in;
            obj.data_out = vif.data_out;
            `uvm_info(get_type_name(), "Sending data to Scoreboard", UVM_NONE)
            obj.print();
            Aobj.write(obj);
        end
    endtask
endclass

// ---------------------- CONFIG CLASS -------------------------
class Config_Dff extends uvm_object;
    `uvm_object_utils(Config_Dff)

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string Name = "Config_Dff");
        super.new(Name);
    endfunction
endclass

// ---------------------- AGENT -------------------------
class My_Agent extends uvm_agent;
    `uvm_component_utils(My_Agent)

    My_Sequencer S;
    My_Driver D;
    My_Monitor M;

    function new(string Name = "My_Agent", uvm_component parent = null);
        super.new(Name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        S = My_Sequencer::type_id::create("S", this);
        D = My_Driver::type_id::create("D", this);
        M = My_Monitor::type_id::create("M", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        D.seq_item_port.connect(S.seq_item_export);
        M.Aobj.connect(s.A_obj);
    endfunction
endclass

// ---------------------- SCOREBOARD -------------------------
class My_Scoreboard extends uvm_scoreboard;
    `uvm_component_utils(My_Scoreboard)

    Sequence_Item obj;
    uvm_analysis_imp #(Sequence_Item, My_Scoreboard) A_obj;

    function new(string Name = "My_Scoreboard", uvm_component parent = null);
        super.new(Name, parent);
        A_obj = new("A_obj", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        obj = Sequence_Item::type_id::create("obj");
    endfunction

    virtual function void write(input Sequence_Item tr);
        `uvm_info(get_type_name(), "Received data from Analysis port", UVM_NONE)
        tr.print();
        if (tr.reset)
            `uvm_info(get_type_name(), "Reset is active", UVM_NONE)
        else if (tr.data_in == tr.data_out)
            `uvm_info(get_type_name(), "Test Passed", UVM_NONE)
        else
            `uvm_error(get_type_name(), "Test Failed")
    endfunction
endclass

// ---------------------- ENVIRONMENT -------------------------
class My_Env extends uvm_env;
    `uvm_component_utils(My_Env)

    My_Agent a;
    My_Scoreboard s;

    function new(string Name = "My_Env", uvm_component parent = null);
        super.new(Name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        s = My_Scoreboard::type_id::create("s", this);
        a = My_Agent::type_id::create("a", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.M.Aobj.connect(s.A_obj);
    endfunction
endclass

// ---------------------- TEST -------------------------
class My_Test extends uvm_test;
    `uvm_component_utils(My_Test)

    My_Env e;
    Config_Dff C;
    Inactive_Reset_Seq adff;
    Active_Reset_Seq rdff;
    Random_Seq rdin;

    function new(string Name = "My_Test", uvm_component parent = null);
        super.new(Name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = My_Env::type_id::create("e", this);
        C = Config_Dff::type_id::create("c", this);
        uvm_config_db#(Config_Dff)::set(this, "*", "Agent_Configuration", C);
        adff = Inactive_Reset_Seq::type_id::create("adff", this);
        rdff = Active_Reset_Seq::type_id::create("rdff", this);
        rdin = Random_Seq::type_id::create("rdin", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        adff.start(e.a.S);
        #50;
        rdff.start(e.a.S);
        #50;
        rdin.start(e.a.S);
        #50;
        phase.drop_objection(this);
    endtask
endclass

// ---------------------- TB TOP MODULE -------------------------

module tb_top;
    bit clock;
    bit reset;

    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end

    initial begin
        reset = 1;
        #100 reset = 0;
    end

    dff_interface vif();
    assign vif.clock = clock;
    assign vif.reset = reset;

    d_ff DUT (
        .clock   (vif.clock),
        .reset   (vif.reset),
        .data_in (vif.data_in),
        .data_out(vif.data_out)
    );

    initial begin
        uvm_config_db#(virtual dff_interface)::set(null, "*", "Virtual Interface", vif);
        run_test("My_Test");
    end
endmodule
