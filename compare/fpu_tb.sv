`timescale 1ns / 1ns

module fpu_tb;

import fpuv_pkg::*; 

parameter CLK_PD = 50;               // system clock period


longint _out;
longint _flags;
int cnt_clock = 0;



parameter ELEN        = 64;
parameter NUM_SRCS    = 3;

logic                                  clk_i = 0;
logic                                  rsn_i;
  // Input signals
logic [NUM_SRCS-1:0][ELEN-1:0]         op_src_i;
fpuv_pkg::frm_e                        op_frm_i;
fpuv_pkg::fp_op_group_e                op_group_i;
fpuv_pkg::fp_op_ctrl_t                 op_ctrl_i;
fpuv_pkg::vsew_e                       op_vsew_i;
fpuv_pkg::fp_src_ctrl_t [NUM_SRCS-1:0] op_src_ctrl_i;
fpuv_pkg::dst_ctrl_e                   op_dst_ctrl_i;
logic [fpuv_pkg::MAX_ELE_FU-1:0]       op_enable_i;
logic [fpuv_pkg::MAX_ELE_FU-1:0]       op_mask_bits_i;
fpuv_pkg::msk_ctrl_t                   op_msk_ctrl_i;
  // Input Handshake
logic                                 op_valid_i;
logic                                 op_ready_o;
logic                                 kill_i;
  // Output signals
logic [ELEN-1:0]                      result_data_o;
fpuv_pkg::fflags_t                    result_flags_o;
  // Output handshake
logic                                 result_valid_o;
logic                                 stall_i;


parameter NDATA = 1000*3;
reg [64-1:0] data_array [0:NDATA-1];

// clock generator
always #(CLK_PD/2) clk_i = ~clk_i;




fpuv_top fpuv_top_i (
  .clk_i(clk_i),
  .rsn_i(rsn_i),
  // Input signals
  .op_src_i(op_src_i),
  .op_frm_i(op_frm_i),
  .op_group_i(op_group_i),
  .op_ctrl_i(op_ctrl_i),
  .op_vsew_i(op_vsew_i),
  .op_src_ctrl_i(op_src_ctrl_i),
  .op_dst_ctrl_i(op_dst_ctrl_i),
  .op_enable_i(op_enable_i),
  .op_mask_bits_i(op_mask_bits_i),
  .op_msk_ctrl_i(op_msk_ctrl_i),
  // Input Handshake
  .op_valid_i(op_valid_i),
  .op_ready_o(op_ready_o),
  .kill_i(kill_i),
  // Output signals
  .result_data_o(result_data_o),
  .result_flags_o(result_flags_o),
  // Output handshake
  .result_valid_o(result_valid_o),
  .stall_i(stall_i)
    );


// control simulation
    initial begin
    int _is_data_exist;
    int file;

    // Open the file
    file = $fopen("output.txt", "w");



///@ <REGION="RESET MODULE"> ------------------------------------------------------------------------START REGION
        @(negedge clk_i);
        rsn_i = 0;   
        repeat (10) @(negedge clk_i);
        rsn_i = 1;
///@ </REGION="RESET MODULE"> ------------------------------------------------------------------------END REGION


// Load data 
$readmemh("./data_in.hex", data_array, 0, NDATA - 1);


for (int i = 0; i < NDATA; i+=3) begin

///@ <REGION="TEST DIV"> ------------------------------------------------------------------------START REGION

op_src_i[0] = data_array[i];
op_src_i[1] = data_array[i+1]; 
op_src_i[2] = data_array[i+2]; 



/// SET THE CONFIGURATION
op_frm_i = FRM_RNE;
op_group_i = FOG_UNARY; // FOG_ADD, FOG_MUL, FOG_FMA, FOG_CMP, FOG_SIGNJ, FOG_UNARY, FOG_DIV_SQRT
op_ctrl_i.unary = FUNA_F2F; // See different structs in fpuv_pkg.sv
//op_ctrl_i.fma.negated = 0; 
op_vsew_i = SEW32;



op_src_ctrl_i[0].widen = 0;
op_src_ctrl_i[1].widen = 0;
op_src_ctrl_i[2].widen = 0;
	//FOG_CMP requires DST_MASK as op_dst_ctr_i
op_dst_ctrl_i = DST_BASE; //DST_BASE, DST_WIDEN, DST_NARROW, DST_MASK
op_enable_i = 'h00;
op_mask_bits_i = 'h00;
op_msk_ctrl_i = 'b000;
op_valid_i = 1;
kill_i = 0;
stall_i = 0;
repeat (1) @(posedge clk_i);
op_valid_i = 0;



while (result_valid_o == 0) begin
  repeat (1) @(negedge clk_i);
  cnt_clock = cnt_clock+1;
end
$fwrite(file, "%x,%x\n", result_flags_o, result_data_o);













$display("%x,%x,%x\n", op_src_i[0], op_src_i[1],op_src_i[2]);
$display("%x,%x\n", result_flags_o, result_data_o);



///@ </REGION="TEST MUL"> ------------------------------------------------------------------------END REGION
repeat (10) @(posedge clk_i);

end


// Close the file
  $fclose(file);

$finish;

        
    end

endmodule
