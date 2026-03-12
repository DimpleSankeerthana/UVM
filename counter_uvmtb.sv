import uvm_pkg::*;
`include "uvm_macros.svh"

module rtl(clk,rst,data,count,mode,load);
    input bit rst;
    input logic[3:0] data;
    output logic [3:0] count;
    input bit mode;
    input bit load;
    input bit clk;

    always@(posedge clk or posedge rst)
    begin
        if(rst)
            count<=0;
        else if(load)
                count<=data;
        else
            case(mode)
            1'b1: count <= (count==11)? 4'b0 : (count+1);
            1'b0: count <= (count==0)? 4'd11 : (count-1);
            endcase
    end
endmodule
//===================================================================
interface counter_if(input bit clock);
    bit rst;
    bit clk;
    bit load;
    bit mode;
    logic[3:0] data;
    logic [3:0] count;

    assign clk = clock;

   modport DUT_MP(input clk, input rst, input mode, input load, input data, output count);

    clocking drv_cb@(posedge clock);
        default input #1 output #1;
        output rst;
        output mode;
        output load;
        output data;
    endclocking

    clocking wmon_cb@(negedge clock);
        default input #1 output #1;
        input rst;
        input load;
        input mode;
        input data;
    endclocking

    clocking rmon_cb@(negedge clock);
        default input #1 output #1;
        input count;
    endclocking

    modport DRV_MP(clocking drv_cb);
    modport WMON_MP(clocking wmon_cb);
    modport RMON_MP(clocking rmon_cb);

endinterface 

class trans extends uvm_sequence_item;
    `uvm_object_utils(trans)
     rand bit load;
     rand bit mode;
     rand bit rst;
     rand logic[3:0] data;
     logic[3:0] count=0;

    constraint value { 
                        mode dist {0 :=40, 1:=60};
                        load dist {1 := 10, 0:=90};}

    function new(string name = "");
        super.new(name);
    endfunction //new()

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("load",this.load,1,UVM_DEC);
        printer.print_field("reset",this.rst, 1, UVM_DEC);
        printer.print_field("mode", this.mode, 1, UVM_DEC);
        printer.print_field("data",this.data, 1, UVM_DEC);
        printer.print_field("count", this.count, 1, UVM_DEC);
    endfunction


endclass //className

class conf extends uvm_object;
`uvm_object_utils(conf)

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual counter_if vif;

    function new(string name = "");
        super.new(name);
    endfunction //new()

endclass //className extends superClass


class seq extends uvm_sequence#(trans);
    `uvm_object_utils(seq)

    function new(string name = "");
        super.new(name);
    endfunction //new()

    task  body();
        repeat(10)
        begin
        req= trans::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {rst==0; load==0;});
        finish_item(req);
        end
    endtask //automatic

endclass 

class rst_seq extends uvm_sequence#(trans);
    `uvm_object_utils(rst_seq)

    function new(string name = "");
        super.new(name);
    endfunction //new()

    task  body(); 
        m_sequencer.grab(this);
        begin
        req= trans::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {rst==1;});
        finish_item(req);
        m_sequencer.ungrab(this);
        end
    endtask //automatic

endclass 

class load_seq extends uvm_sequence#(trans);
    `uvm_object_utils(load_seq)

    function new(string name = "");
        super.new(name);
    endfunction //new()

    task  body();
        m_sequencer.grab(this);
        begin
        req= trans::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {load==1; rst==0;});
        finish_item(req);
        m_sequencer.ungrab(this);

        end
    endtask //automatic

endclass 

class seqr extends uvm_sequencer#(trans);
    `uvm_component_utils(seqr)

  function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction //new()

     function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
endclass //seq


class drv extends uvm_driver#(trans);
    `uvm_component_utils(drv)
    conf cfg;
    virtual counter_if.DRV_MP vif;
    function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction

     function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(conf)::get(this,"","conf",cfg))
            `uvm_fatal("FATAL", "CONFIG FAILED IN driver")
        vif = cfg.vif.DRV_MP;
    endfunction

    task  run_phase(uvm_phase phase);
        forever begin
        seq_item_port.get_next_item(req);
        $display("==========DRIVER DATA============");
        req.print();
        drive(req);
        seq_item_port.item_done();
        end
    endtask

    task  drive(trans req);
        @(vif.drv_cb);
            vif.drv_cb.load<=req.load;
            vif.drv_cb.rst<=req.rst;
            vif.drv_cb.mode<=req.mode;
            vif.drv_cb.data<=req.data;
        @(vif.drv_cb);
        vif.drv_cb.rst <= 0;
        vif.drv_cb.load   <= 0;
        vif.drv_cb.data   <= 0;
        vif.drv_cb.mode  <= 0;
    endtask

endclass //drv

class rmon extends uvm_monitor;
    `uvm_component_utils(rmon)
     virtual counter_if.RMON_MP vif;
     conf cfg;
    uvm_analysis_port#(trans) mon_port;

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
        mon_port = new("mon_port",this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(conf)::get(this,"","conf",cfg))
            `uvm_fatal("FATAL", "CONFIG FAILED IN MONITOR")
        vif=cfg.vif.RMON_MP;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            collect();
        end
    endtask //automatic

    task collect();
        trans req;
        req=trans::type_id::create("req");

        @(vif.rmon_cb);

        req.count = vif.rmon_cb.count;
       

        mon_port.write(req);
        $display("=========== READ MONITOR DATA============");
        req.print();
    endtask //automatic
endclass //mon

class wmon extends uvm_monitor;
    `uvm_component_utils(wmon)
     virtual counter_if.WMON_MP vif;
     conf cfg;
    uvm_analysis_port#(trans) mon_port;

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
        mon_port = new("mon_port",this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(conf)::get(this,"","conf",cfg))
            `uvm_fatal("FATAL", "CONFIG FAILED IN MONITOR")
        vif=cfg.vif.WMON_MP;
    endfunction

    task run_phase(uvm_phase phase);
        
        forever begin
            collect();
        end
    endtask //automatic

    task collect();
        trans req;
        req=trans::type_id::create("req");

        @(vif.wmon_cb);

        req.load = vif.wmon_cb.load;
        req.rst=vif.wmon_cb.rst;
        req.data=vif.wmon_cb.data;
        req.mode=vif.wmon_cb.mode;

        mon_port.write(req);
        $display("===========WRITE MONITOR DATA============");
        req.print();
    endtask //automatic
endclass //mon


class ragent extends uvm_agent;
    `uvm_component_utils(ragent)

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction //new()

    drv drvh;
    rmon monh;
    seqr seqrh;
    conf cfg;

 function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(conf)::get(this,"","conf",cfg))
            `uvm_fatal("FATAL", "CONFIG FAILED IN agent")

        monh = rmon::type_id::create("monh",this);
        if(cfg.is_active==UVM_ACTIVE)
            begin
                    drvh= drv::type_id::create("drvh",this);
                    seqrh=seqr::type_id::create("seqrh",this);
            end
    endfunction

function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(cfg.is_active==UVM_ACTIVE)
        drvh.seq_item_port.connect(seqrh.seq_item_export);
endfunction


endclass 

class wagent extends uvm_agent;
    `uvm_component_utils(wagent)

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction //new()

    drv drvh;
    wmon monh;
    seqr seqrh;
    conf cfg;

 function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(conf)::get(this,"","conf",cfg))
            `uvm_fatal("FATAL", "CONFIG FAILED IN agent")

        monh = wmon::type_id::create("monh",this);
        if(cfg.is_active==UVM_ACTIVE)
            begin
                    drvh= drv::type_id::create("drvh",this);
                    seqrh=seqr::type_id::create("seqrh",this);
            end
    endfunction

function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(cfg.is_active==UVM_ACTIVE)
        drvh.seq_item_port.connect(seqrh.seq_item_export);
endfunction


endclass 
//===================================================================
class v_seqr extends uvm_sequencer#(uvm_sequence_item);
        seqr seqrh;

     `uvm_component_utils(v_seqr)

  function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction //new()

endclass
class v_seq extends uvm_sequence#(uvm_sequence_item);
        `uvm_object_utils(v_seq)
        seq seqh;
        rst_seq rseqh;
        load_seq lseqh;
        seqr seqrh;
        v_seqr vseqrh;

         function new(string name = "");
            super.new(name);
        endfunction //new()

        task body();
            if(!$cast(vseqrh,m_sequencer))
                `uvm_fatal("FATAL", " casting of msequencer  failed")

            seqrh=vseqrh.seqrh;

            seqh = seq::type_id::create("seqh");
            rseqh= rst_seq::type_id::create("rseqh");
            lseqh = load_seq::type_id::create("lseqh");

            fork
                rseqh.start(seqrh);
                lseqh.start(seqrh);
                seqh.start(seqrh);
            join
        endtask


endclass
class sb extends uvm_scoreboard;
    `uvm_component_utils(sb)

    uvm_tlm_analysis_fifo#(trans) fifo_wh;
    uvm_tlm_analysis_fifo#(trans) fifo_rh;
    trans req_w;
    trans req_r;
    logic[3:0] ref_data;
    function new(string name="", uvm_component parent);
        super.new(name,parent);
        fifo_wh=new("fifo_wh",this);
        fifo_rh=new("fifo_rh",this);

    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ref_data=0;
    endfunction

    task  run_phase(uvm_phase phase);
        forever begin
        fifo_wh.get(req_w);
        fifo_rh.get(req_r);
        if(compare(req_r,ref_data))
                `uvm_info("INFO","comparision sucessful",UVM_LOW)
        else
                `uvm_info("INFO", "FAILED",UVM_LOW)
        check_data(req_w);
        $display("=======REFERENCE MODEL | data out : %0d ===========",ref_data);
        end
    endtask
    task check_data(trans req_w);
        if(req_w.rst)
            ref_data =0;
        else if(req_w.load)
                ref_data = req_w.data;
        else
            case(req_w.mode)
            1'b1: ref_data = (ref_data==11)? 4'b0 : (ref_data+1);
            1'b0: ref_data = (ref_data==0)? 4'd11 : (ref_data-1);
            endcase
    endtask

    function bit compare(trans req, logic[3:0] ref_data);
         $display("===================SCORE BOARD =================");
        $display("reference model : %0d | read monitor data : %0d", ref_data, req.count);
        if(req.count==ref_data)
                return(1);
        else
                return(0);
    endfunction
endclass

//===================================================================

class env extends uvm_env;
    `uvm_component_utils(env)

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction //new()

    wagent wagnth;
    ragent ragnth;
    sb sbh;
    conf wcfg;
    conf rcfg;
    conf cfg;
    v_seqr vseqrh;

     function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(conf)::get(this,"","cfg",cfg))
                    `uvm_fatal("ENV","CONFIG NOT FOUND")

        wagnth = wagent::type_id::create("wagnth",this);
        ragnth = ragent::type_id::create("ragnth",this);
        vseqrh= v_seqr::type_id::create("v_seqr",this);

        wcfg = conf::type_id::create("wcfg",this);
        rcfg = conf::type_id::create("rcfg",this);

        sbh = sb::type_id::create("sbh",this);

        wcfg.vif = cfg.vif;
        rcfg.vif = cfg.vif;

        wcfg.is_active=UVM_ACTIVE;
        uvm_config_db#(conf)::set(this,"wagnth*","conf",wcfg);
        rcfg.is_active=UVM_PASSIVE;
        uvm_config_db#(conf)::set(this,"ragnth*","conf",rcfg);
       

    endfunction

     function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        wagnth.monh.mon_port.connect(sbh.fifo_wh.analysis_export);
        ragnth.monh.mon_port.connect(sbh.fifo_rh.analysis_export);

        vseqrh.seqrh = wagnth.seqrh;

    endfunction

endclass //className extends superClass
//===================================================================

class test extends uvm_test;

    `uvm_component_utils(test)

    function new(string name = "", uvm_component parent);
        super.new(name,parent);
    endfunction

    env envh;
    seq seqh;
    conf cfg;
    v_seq vseqh;

     function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cfg=conf::type_id::create("cfg");
        
        if(!uvm_config_db#(virtual counter_if)::get(this,"","vif",cfg.vif))
            `uvm_fatal("FATAL", "CONFIG FAILED IN TEST")

        uvm_config_db#(conf)::set(this,"*","cfg",cfg);
        envh = env::type_id::create("envh",this);

    endfunction

     function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
    endfunction

     task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            vseqh = v_seq::type_id::create("vseqh");
            vseqh.start(envh.vseqrh);
        phase.drop_objection(this);
    endtask 

endclass
//===================================================================

module top;
    import uvm_pkg::*;
    bit clk=0;
    counter_if vif(clk);

    rtl dut(.clk(vif.DUT_MP.clk), .rst(vif.DUT_MP.rst), .mode(vif.DUT_MP.mode), .load(vif.DUT_MP.load),
     .data(vif.DUT_MP.data),.count(vif.DUT_MP.count));

    bind rtl assertions assr( .clk(clk),
                                .rst(rst),
                                .data(data),
                                .count(count),
                                .mode(mode),
                                .load(load));
    initial forever begin
        #5 clk = ~clk;
    end

    initial begin
        uvm_config_db#(virtual counter_if)::set(null,"*","vif",vif);
        run_test("test");
    end
endmodule


