`timescale 1ns / 1ps

`include "../../../usr-ip-lib/common_hdl/interfaces/axis_intf.svh"

module xFFT_wrapper
#(parameter
  DIRECTION    = 0         // 0 for fft, 1 for ifft
  )(
  input   logic           aclk,
  input   logic           aclken,
  input   logic           aresetn,
  input   logic  [4:0]    i_nFFT,
  input   logic  [9:0]    i_cp_len,
  input   logic  [7:0]    i_scale,
  input   logic           i_cfg_valid,
  output  logic           o_cfg_ready,
  output  logic   [7:0]   o_status_tdata,
  output  logic           o_status_tvalid,
  output  logic           o_event_error,

  AXIS.Slave              s_axis,
  AXIS.Master             m_axis
    );
    
    
logic            event_data_in_channel_halt_0;
logic            event_data_out_channel_halt_0;
logic            event_frame_started_0;
logic            event_status_channel_halt_0;
logic            event_tlast_missing_0;
logic            event_tlast_unexpected_0;
logic   [31:0]   cfg_data,       cfg_data_p;
logic   [12:0]   fft_counter;
logic   [9:0]    cp_len_counter;
logic            cfg_valid,      cfg_valid_p;



//------------------------------------------------------------------
always @(posedge aclk or negedge aresetn)
  if(~aresetn) begin
    fft_counter     <= 'd0;
    cp_len_counter  <= 'd0;
    cfg_valid       <= 'd0;
    cfg_data        <= 'd0;
    cfg_data_p      <= 'd0;
  end else begin
    if(s_axis.tlast)
      fft_counter  <= 'd0;
    else if (s_axis.tvalid)
      fft_counter <= fft_counter + 'd1;

    if(s_axis.tlast && (s_axis.tvalid == 1'b1))
      cp_len_counter  <= 'd0;
    else if (s_axis.tvalid == 1'b0)
      cp_len_counter <= cp_len_counter + 'd1;

    cfg_valid     <=  i_cfg_valid;
    cfg_data_p    <=  cfg_data;
    if ((i_cfg_valid == 1'b1) && (cfg_valid == 1'b0)) begin // capture the changes at the rising edge of valid signal
      cfg_data    <= {6'd0, 2'b00, 6'd0, i_cp_len, 3'd0, i_nFFT};
    end

    if ( ( cfg_data_p != cfg_data) && cfg_valid )// Apply the changes only if the configs are changed
      cfg_valid_p  <=  1'b1;
    else
      cfg_valid_p  <=  1'b0;


  end

assign   o_event_error =  event_data_in_channel_halt_0 | event_data_out_channel_halt_0 | event_status_channel_halt_0 | event_tlast_missing_0 | event_tlast_unexpected_0;

fft_bd fft_bd_i_2 (
  .M_AXIS_DATA_0_tdata            ( m_axis.tdata         ),
  .M_AXIS_DATA_0_tlast            ( m_axis.tlast         ),
  .M_AXIS_DATA_0_tready           ( m_axis.tready        ),
  .M_AXIS_DATA_0_tuser            ( m_axis.tuser         ),
  .M_AXIS_DATA_0_tvalid           ( m_axis.tvalid        ),
 
  .M_AXIS_STATUS_0_tdata          ( o_status_tdata       ),
  .M_AXIS_STATUS_0_tready         ( 1'b1                 ),
  .M_AXIS_STATUS_0_tvalid         ( o_status_tvalid      ),
 
  .S_AXIS_CONFIG_0_tdata          ( cfg_data_p           ),
  .S_AXIS_CONFIG_0_tready         ( o_cfg_ready          ),
  .S_AXIS_CONFIG_0_tvalid         ( cfg_valid_p          ),
 
  .S_AXIS_DATA_0_tdata            ( s_axis.tdata         ),
  .S_AXIS_DATA_0_tlast            ( s_axis.tlast         ),
  .S_AXIS_DATA_0_tready           ( s_axis.tready        ),
  .S_AXIS_DATA_0_tvalid           ( s_axis.tvalid        ),
  .aclk_0                         ( aclk                 ),
  .aclken_0                       ( aclken               ),
  .aresetn_0                      ( aresetn              ),
 
  .event_data_in_channel_halt_0   ( event_data_in_channel_halt_0   ),
  .event_data_out_channel_halt_0  ( event_data_out_channel_halt_0  ),
  .event_frame_started_0          ( event_frame_started_0          ),
  .event_status_channel_halt_0    ( event_status_channel_halt_0    ),
  .event_tlast_missing_0          ( event_tlast_missing_0          ),
  .event_tlast_unexpected_0       ( event_tlast_unexpected_0       )
);

endmodule


