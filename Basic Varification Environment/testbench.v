`include "uvm_macros.svh"
import uvm_pkg::*;

class Sequence_Item extends uvm_sequence_item;
    rand bit reset;     // Active-high reset
    rand bit data_in;   // Input data
    bit data_out;       // Output data

    // UVM automation macros for printing, copying, etc.
    `uvm_object_utils_begin(Sequence_Item)
        `uvm_field_int(reset,    UVM_DEFAULT)
        `uvm_field_int(data_in,  UVM_DEFAULT)
        `uvm_field_int(data_out, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "sequence_item");
        super.new(name);
    endfunction
endclass: Sequence_Item

// When reset is not active 
class Inactive_Reset_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Inactive_Reset_Seq)

    Sequence_Item obj;

    function new(string Name = "Inactive_Reset_Seq");
        super.new(Name);
    endfunction
    
    virtual task body();
        obj = Sequence_Item::type_id::create("obj");
        repeat(10) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b0;
            `uvm_info(get_type_name(), "Driver Send data with reset is inactive", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass: Inactive_Reset_Seq

// When reset is active
class Active_Reset_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Active_Reset_Seq)

    Sequence_Item obj;

    function new(string Name = "Active_Reset_Seq");
        super.new(Name);
    endfunction
    
    virtual task body();
        obj = Sequence_Item::type_id::create("obj");
        repeat(10) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b1;
            `uvm_info(get_type_name(), "Driver Send data with active reset", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass: Active_Reset_Seq

// When reset and din is randomized
class Random_Seq extends uvm_sequence#(Sequence_Item);
    `uvm_object_utils(Random_Seq)
    
    Sequence_Item obj;

    function new(string Name = "Random_Seq");
        super.new(Name);
    endfunction
    
    virtual task body();
        obj = Sequence_Item::type_id::create("obj");
        repeat(10) begin
            start_item(obj);
            void'(obj.randomize());
            obj.reset = 1'b0;
            `uvm_info(get_type_name(), "Driver Send data with randomization", UVM_NONE)
            obj.print();
            finish_item(obj);
        end
    endtask
endclass: Random_Seq

class My_Sequencer extends uvm_sequencer #(Sequence_Item);
    `uvm_component_utils(My_Sequencer)
    
    function new(string Name="My_Sequencer", uvm_component parent);
        super.new(Name, parent);
    endfunction
endclass: My_Sequencer

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
        if (!uvm_config_db#(virtual dff_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "Virtual interface not found in config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            // Get next transaction from sequencer
            seq_item_port.get_next_item(obj);
            
            // Drive signals to DUT
            vif.reset   <= obj.reset;
            vif.data_in <= obj.data_in;
            
            `uvm_info(get_type_name(), "Data Send to DUT", UVM_NONE)
            
            // Complete transaction handshake
            seq_item_port.item_done();
            
            // Wait for 2 clock cycles (if needed for DUT timing)
            repeat(2) @(vif.clock);
        end
    endtask
endclass: My_Driver

class My_Monitor extends uvm_monitor;
    `uvm_component_utils(My_Monitor)
    
    Sequence_Item obj;
    virtual dff_interface vif;
    uvm_analysis_port #(Sequence_Item) Aobj;
    
    function new(string Name = "My_Monitor", uvm_component parent = null);
        super.new(Name, parent);
        Aobj = new("A_obj", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        obj = Sequence_Item::type_id::create("obj", this);
        if(!uvm_config_db#(virtual dff_interface)::get(this, "", "vif", vif))
            `uvm_error(get_type_name(), "Unable to access the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            repeat(2) @(posedge vif.clock);
            obj.reset = vif.reset;
            obj.data_in = vif.data_in;
            obj.data_out = vif.data_out;
            `uvm_info(get_type_name(), "Send data to Scoreboard", UVM_NONE);
            obj.print();
            Aobj.write(obj);
        end
    endtask
endclass: My_Monitor

class Config_Dff extends uvm_object;
    `uvm_object_utils(Config_Dff)

    uvm_active_passive_enum agent_type = UVM_ACTIVE;

    function new(string Name = "Config_Dff");
        super.new(Name);
    endfunction
endclass: Config_Dff

class My_Agent extends uvm_agent;
    `uvm_component_utils(My_Agent)

    function new(string Name = "My_Agent", uvm_component parent = null);
        super.new(Name, parent);
    endfunction

    My_Sequencer S;
    My_Driver D;
    My_Monitor M;
    Config_Dff C;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        M = My_Monitor::type_id::create("M", this);
        C = Config_Dff::type_id::create("C", this);
        if(!uvm_config_db#(Config_Dff)::get(this, "", "Agent_Configuration", C)) begin
            `uvm_info(get_type_name(), 
                     "Failed to access the config - Using defaults", 
                     UVM_MEDIUM)
        end
        if(C.agent_type == UVM_ACTIVE) begin
            D = My_Driver::type_id::create("D", this);
            S = My_Sequencer::type_id::create("S", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(C.agent_type == UVM_ACTIVE) begin
            D.seq_item_port.connect(S.seq_item_export);
        end
    endfunction
endclass: My_Agent

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
        if (tr.reset) begin
            `uvm_info(get_type_name(), "Active Reset", UVM_MEDIUM)
        end
        else if (!tr.reset && (tr.data_in == tr.data_out)) begin
            `uvm_info(get_type_name(), "Test Passed", UVM_MEDIUM)
        end
        else begin
            `uvm_info(get_type_name(), "Test Failed", UVM_MEDIUM)
        end
    endfunction
endclass: My_Scoreboard

// Environment
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
endclass: My_Env

class My_Test extends uvm_test;
    `uvm_component_utils(My_Test)
    
    My_Env e;
    Config_Dff C;
    
    // Sequences
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
        uvm_config_db#(Config_Dff)::set(this,"*","Agent_Configuration", C);
        adff = Inactive_Reset_Seq::type_id::create("adff", this);
        rdff = Active_Reset_Seq::type_id::create("rdff", this);
        rdin = Random_Seq::type_id::create("rdin", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        adff.start(e.a.S);
        #40;
        rdff.start(e.a.S);
        #40;
        rdin.start(e.a.S);
        #40;
        phase.drop_objection(this);
    endtask
endclass: My_Test

module tb_top;
    // Clock generation
    bit clock;
    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end

    // Instantiate interface and DUT
    dff_interface vif();
    d_ff DUT (
        .clock   (vif.clock),
        .reset   (vif.reset),
        .data_in (vif.data_in),
        .data_out(vif.data_out)
    );

    initial begin
        // Pass virtual interface to UVM environment
        uvm_config_db#(virtual dff_interface)::set(null, "*", "vif", vif);
        
        // Start UVM test
       run_test("My_Test");
    end

    // Dump waveforms
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end
endmodule: tb_top