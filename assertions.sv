module assertions(
            clk,rst,data,count,mode,load
);
    input bit rst;
    input logic[3:0] data;
    input logic [3:0] count;
    input bit mode;
    input bit load;
    input bit clk;

    property reset; 
        @(posedge clk)
            (rst) |-> count==0;
    endproperty

    property load_prp; 
        @(posedge clk)
            disable iff(rst)
            (load) |=> count==$past(data);
    endproperty

    property up_prp; 
        @(posedge clk)
            disable iff(rst)
            ((!load)&&(mode)) |=> if(count)
                                        count==0
                                    else
                                        count== ($past(count)+1);
    endproperty

    property down_prp; 
        @(posedge clk)
            disable iff(rst)
                ((!load)&&(!mode)) |=> if(count==0)
                                            count==11
                                        else
                                            count== ($past(count) -1);

    endproperty

    assert property(reset)
        $display("RESET SUCCESSFUL");
    else
        $display("RESET FAILED");

    assert property(load_prp)
        $display("LOAD SUCCESSFUL");
    else
        $display("LOAD FAILED");

    assert property(up_prp)
        $display("UP COUNT CHECK SUCCESSFUL");
    else
        $display("UP COUNT CHECK FAILED");

    assert property(down_prp)
        $display("DOWN COUNT CHECK SUCCESSFUL");
    else
        $display("DOWN COUNT CHECK FAILED");

endmodule