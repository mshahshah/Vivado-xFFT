`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/11/2021 05:30:36 PM
// Design Name: 
// Module Name: tb_ifft
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_ifft (    );
    

parameter        NC         = 1; // Number of channels
parameter [4:0]  NFFT       = 5'd10;
parameter [9:0]  FFT_CP_LEN = 'd72;
parameter [1:0]  FWD_INV    = 2'b01;
parameter [7:0]  SCALE_SCH  = 'd0;
parameter        nSymbols   = 4;
parameter        FFT_size   = 'd1024;
parameter        CP_size    = 'd72;

parameter src_file1   = "C:/Users/mshahshahani/Documents/FPGA_Projects/test_fft/stimulus_files/xFFT_input_1024_4symb.csv";
parameter dest_file1  = "C:/Users/mshahshahani/Documents/FPGA_Projects/test_fft/stimulus_files/hw_xfft_output_C1.csv";
parameter rtl_cfg_var = "C:/Users/mshahshahani/Documents/FPGA_Projects/test_fft/rtl_cfg_var.txt";

`define NULL 0  

logic  [32-1:0]  m_axis_tdata;
logic   [8-1:0]  m_axis_tuser;
logic            m_axis_tlast,
                 m_axis_tready,
                 m_axis_tvalid;

logic   [8-1:0]  m_axis_status_tdata;
logic            m_axis_status_tready;
logic            m_axis_status_tvalid;

logic [32-1:0]   s_axis_tdata;
logic            s_axis_tlast;
logic            s_axis_tvalid;
logic            s_axis_tready;

logic   [31:0]   ifft_cfg_i;
logic [32-1:0]   cfg_data;
logic            cfg_ready;
logic            cfg_v;

logic   event_data_in_channel_halt_0;
logic   event_data_out_channel_halt_0;
logic   event_frame_started_0;
logic   event_status_channel_halt_0;
logic   event_tlast_missing_0;
logic   event_tlast_unexpected_0;



logic [15:0]  sample_per_symbol_idx;
logic  [3:0]  symbol_per_slot_idx;
logic  [9:0]  symbol_per_sf_idx;
logic         symbol_strobe;
logic         slot_strobe;



logic rst, CLK125;
logic begin_sim, stop_sim, send_data, start_ifft_comp;
logic signed [15:0] Din_I1, Din_Q1;
logic signed [15:0] Dout_I1, Dout_Q1;


logic  [3:0]  SM; // state machine
logic  [1:0]  SM_cfg;
logic  [5:0]  pkt_injected;
logic  [5:0]  pkt_extracted;


integer		data_file1, data_file2, data_file3, data_file4, cfg_file;
integer     scan1, scan2, scan3, scan4, scan5, scan6;



assign {Dout_Q1,Dout_I1} = m_axis_tdata;
assign ifft_cfg_i[24]   = FWD_INV;
assign ifft_cfg_i[17:8] = FFT_CP_LEN;
assign ifft_cfg_i[4:0]  = NFFT;

//assign ifft_cfg_i        = {6'd0, FWD_INV};
assign s_axis_tdata      = {Din_Q1, Din_I1};
assign start_ifft_comp   = symbol_strobe & (symbol_per_slot_idx == 'd1);

always #4 CLK125 = ~ CLK125;

initial begin
	data_file1 = $fopen(src_file1, "r");
	if (data_file1 == `NULL) begin
		$display("data_file handle was NULL");
	end  

	data_file3 = $fopen(dest_file1,"w");
   
   cfg_file = $fopen(rtl_cfg_var, "w");
   $fwrite(cfg_file, "NFFT        : %d\n", NFFT);
   $fwrite(cfg_file, "FFT_CP_LEN  : %d\n", FFT_CP_LEN);
   $fwrite(cfg_file, "FWD_INV     : %d\n", FWD_INV);
   $fwrite(cfg_file, "SCALE_SCH   : %d\n", SCALE_SCH);
   $fclose(cfg_file);

	CLK125=0;
	rst=1;
	pkt_injected=1;
   begin_sim=0;
#23	rst=0;
#200 begin_sim=1;
#202 begin_sim=0;
end

//------------------------------------------------------------------


always @(posedge CLK125 or posedge rst) begin
  if(rst) begin
	Din_I1 <= 0;
	Din_Q1 <= 0;
  end else begin
	if(send_data)
		scan1 = $fscanf(data_file1, "%d,%d\n", Din_Q1, Din_I1);
   else begin
   	Din_I1 <= 0;
      Din_Q1 <= 0;
   end
		
  end // if reset
end // always


logic [15:0] temp_ctr='d0;
//------------------------------------------------------------------
always @(posedge CLK125 or posedge rst) begin
   if(rst) begin
	pkt_extracted  <= 'd0;
   temp_ctr       <= 'd0;
   end else begin
      if(m_axis_tvalid) begin
         $fwrite(data_file3, "%d,%d\n", Dout_Q1, Dout_I1);
         temp_ctr <= temp_ctr + 'd1;
      end else begin
         temp_ctr <= 'd0;
         $fwrite(data_file3, "%d,%d\n", 'd0, 'd0);
      end
      
      if (m_axis_tlast)
         pkt_extracted <= pkt_extracted + 'd1;

   end
end // always

//------------------------------------------------------------------
always @(posedge CLK125 or posedge rst) begin
    if (rst) begin
        cfg_data <=  'd0;
        cfg_v    <=  'd0;
        SM_cfg   <=  'd0;
    end else begin
    
        case ( SM_cfg )
        2'b00: 	begin // idle
                cfg_data <= 'd0;
                cfg_v    <= 'd0;
                if (cfg_ready && s_axis_tready && begin_sim)
                    SM_cfg   <= 2'b01;
                end 

        2'b01: 	begin // set a config
                cfg_data <= ifft_cfg_i;
                cfg_v    <= 'd1;
                SM_cfg   <= 2'b10;
                end
        
        2'b10: 	begin // start the engine
                cfg_data <= 'd0;
                cfg_v    <= 'd0;
                end
                                        
        default: 	begin  
                cfg_data <= 'd0;
                cfg_v    <= 'd0;
                SM_cfg   <= 2'b00;
                    $stop;
                end 
        endcase	
	
end // end reset
end // end always




typedef enum logic [3:0] {
   IDLE,
   WAIT_BEGIN,
   PAD1,
   XFFT_DATA,
   XFFT_END_DATA,
   PAD2,
   NEXT_PKT,
   END_PKT}  sm_states_def;

sm_states_def   SM;
//-------------------------------------------------------------------------------------
always @(posedge CLK125 or posedge rst) begin
	if (rst) begin
		s_axis_tlast         <= 1'b0;
		s_axis_tvalid        <= 1'b0;
		send_data            <= 1'b0;
		SM                   <= IDLE;
		m_axis_tready        <= 1'b1;
		m_axis_status_tready <= 1'b1;
      stop_sim             <= 1'b0;
	end else begin
   case ( SM )
      IDLE: 	begin // idle
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b0;
               send_data     <= 1'b0;
               pkt_injected  <= 'd1;
               if(begin_sim)
                  SM <= WAIT_BEGIN;
				
            end 
      WAIT_BEGIN: 	begin // start to send symbol
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b0;
               if ( s_axis_tready & start_ifft_comp ) begin
                  send_data   <= 1'b0;
                  SM          <= PAD1;		
                  end			
            end     

	   PAD1: 	begin // sending symbol
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b0;
               send_data     <= 1'b0;
               if(sample_per_symbol_idx == (CP_size/2))
                  SM <= XFFT_DATA;
            end 
            
	   XFFT_DATA: 	begin // sending symbol
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b1;
               send_data     <= 1'b1;
               if(sample_per_symbol_idx == (FFT_size + (CP_size/2)-1))
                  SM <= XFFT_END_DATA;
            end 

	   XFFT_END_DATA: 	begin // send symbol + tlast
               s_axis_tlast  <= 1'b1;
               s_axis_tvalid <= 1'b1;
               send_data     <= 1'b1;
               SM            <= PAD2;
            end 
		
	   PAD2: 	begin // end of padding 
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b0;
               send_data     <= 1'b0;
               if(sample_per_symbol_idx == 'd1094)
                  SM <= NEXT_PKT;
            end 
            
	   NEXT_PKT: 	begin // end of gap 
               if(pkt_injected == nSymbols) begin
                  SM <= END_PKT;			
               end else begin
                  SM <= PAD1;
                  pkt_injected <= pkt_injected + 1;
               end
            
            end 					
	   END_PKT: 	begin // stop simulation 
               if(pkt_extracted == nSymbols) begin
                  SM            <= IDLE;
                  s_axis_tlast  <= 1'b0;
                  s_axis_tvalid <= 1'b0;
                  send_data     <= 1'b0;
                  stop_sim      <= 1'b1;
                  $fclose(data_file1);
                  #200 $stop;					
               end else begin
                    SM <= END_PKT;
               end
            end 				
      default: 	begin  
               s_axis_tlast  <= 1'b0;
               s_axis_tvalid <= 1'b0;
               send_data     <= 1'b0;	
               $fclose(data_file1);			
               $stop;
            end 
   endcase	
	
end // end reset
end // end always


fft_bd_wrapper fft_bd_i (
   .M_AXIS_DATA_0_tdata       (m_axis_tdata),
   .M_AXIS_DATA_0_tlast       (m_axis_tlast),
   .M_AXIS_DATA_0_tready      (m_axis_tready),
   .M_AXIS_DATA_0_tuser       (m_axis_tuser),
   .M_AXIS_DATA_0_tvalid      (m_axis_tvalid),

   .M_AXIS_STATUS_0_tdata     (m_axis_status_tdata),
   .M_AXIS_STATUS_0_tready    (m_axis_status_tready),
   .M_AXIS_STATUS_0_tvalid    (m_axis_status_tvalid),

   .S_AXIS_CONFIG_0_tdata     (cfg_data),
   .S_AXIS_CONFIG_0_tready    (cfg_ready),
   .S_AXIS_CONFIG_0_tvalid    (cfg_v),

   .S_AXIS_DATA_0_tdata       (s_axis_tdata),
   .S_AXIS_DATA_0_tlast       (s_axis_tlast),
   .S_AXIS_DATA_0_tready      (s_axis_tready),
   .S_AXIS_DATA_0_tvalid      (s_axis_tvalid),

   .aclk_0                    (CLK125),
   .event_data_in_channel_halt_0(event_data_in_channel_halt_0),
   .event_data_out_channel_halt_0(event_data_out_channel_halt_0),
   .event_frame_started_0(event_frame_started_0),
   .event_status_channel_halt_0(event_status_channel_halt_0),
   .event_tlast_missing_0(event_tlast_missing_0),
   .event_tlast_unexpected_0(event_tlast_unexpected_0)
);

time_controller
  #(.TLRC_ERR      (500),     // number of tics
    .CLK_FREQ      (122880000),     // in Hz
    .CLKS_PER_PPS  (1250), // kept separated from CLK_FREQ for debug purposes
    .TIME_NOT_FREQ (1),
    .NUMEROLOGY    (3)
    )
tc
  (.CLK                    (CLK125),
   .RESET                  (rst),
   .PPS_IN                 (begin_sim),
   .RESYNCH                (1'b1),
   .DELAY_WRT_PPS          ('d100),
   .PPS_CODE               (),
   .SAMPLE_PER_SYMBOL_IDX  (sample_per_symbol_idx),
   .SYMBOL_STROBE          (symbol_strobe),
   .SYMBOL_PER_SLOT_IDX    (symbol_per_slot_idx),
   .SYMBOL_PER_SF_IDX      (symbol_per_sf_idx),
   .SLOT_STROBE            (slot_strobe),
   .SLOT_IDX               (),
   .SUBFRAME_STROBE        (),
   .SUBFRAME_IDX           (),
   .FRAME_STROBE           (),
   .FRAME_IDX              ()
   );
      
      



endmodule
