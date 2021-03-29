//-----------------------------------------------------------------------------
// Title         : Time controller
// Project       : iota
//-----------------------------------------------------------------------------
// File          : time_controller.v
// Author        : Giulio Gabelli  <ggabelli@blq00333dt>
// Created       : 24.07.2019
// Last modified : 24.07.2019
//-----------------------------------------------------------------------------
// Description :
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by JMA Wireless This model is the confidential and
// proprietary property of JMA Wireless and the possession or use of this
// file requires a written license from JMA Wireless.
//------------------------------------------------------------------------------
// Modification history :
// 24.07.2019 : created
//-----------------------------------------------------------------------------


module time_controller
  #(parameter
    TLRC_ERR = 500,    // number of tics
    CLK_FREQ = 245760000, // in Hz
    CLKS_PER_PPS = 245760000, // kept separated from CLK_FREQ for debug purposes
    TIME_NOT_FREQ = 1,
    NUMEROLOGY = 3
    )
   (
    // inputs
    input wire         CLK,
    input wire         RESET,
    //
    input wire         PPS_IN,
    input wire         RESYNCH,
    input wire [31:0]  DELAY_WRT_PPS, // in tics (must be larger than 3)
    //
    output reg [2:0]   PPS_CODE,
    // outputs
    output wire [15:0] SAMPLE_PER_SYMBOL_IDX,
    output reg         SYMBOL_STROBE,
    output reg [3:0]   SYMBOL_PER_SLOT_IDX,
    output reg [9:0]   SYMBOL_PER_SF_IDX,
    output reg         SLOT_STROBE,
    output reg [6:0]   SLOT_IDX,
    output reg         SUBFRAME_STROBE,
    output reg [3:0]   SUBFRAME_IDX,
    output reg         FRAME_STROBE,
    output reg [9:0]   FRAME_IDX
    );


   function integer  calc_long_symbol_idx( input integer   which,
                                           time_not_freq,
                                           numerology);
      begin
      calc_long_symbol_idx = time_not_freq ?
                             ( which ?
                               7 * 2**numerology :
                               0) :
                             ( which ?
                               (7  * 2**numerology)-1 :
                               (14 * 2**numerology)-1 );
      end
   endfunction

   localparam
     MIN_DELAY = 32'd3;

   localparam
     Fc = 4096*32*15000,
     N_u_mu = 2048*64 / (2**(NUMEROLOGY)),
     N_CP_mu = 144*64 / (2**(NUMEROLOGY)) ,
     N_CP_mu_0 = N_CP_mu + 16*64 ,
     Fc_div_CLK = Fc / CLK_FREQ ,
     SYMB_LONG_DURATION = (N_u_mu + N_CP_mu_0 ) / Fc_div_CLK,  // in tics
     SYMB_SHORT_DURATION = (N_u_mu + N_CP_mu ) / Fc_div_CLK;     // in tics

   localparam
     PPS_IDLE        = 0,
     PPS_FIRST_PPS   = 1,
     PPS_SYNC        = 2,
     PPS_NO_SYNC     = 3,
     PPS_NO_PPS      = 4;

   localparam
     TCS_SYNC_DELAY    = 0,
     TCS_SYNC          = 1,
     TCS_NO_SYNC       = 2,
     TCS_CHECK         = 3,
     TCS_ASYNC_DELAY   = 4,
     TCS_ASYNC_RUN     = 5;

   localparam
     POS_ERR_TLRC = CLKS_PER_PPS+TLRC_ERR,
     NEG_ERR_TLRC = CLKS_PER_PPS-TLRC_ERR,
     TIME_BEFORE_NO_PPS = CLKS_PER_PPS*5;

   localparam
     SYMBOLS_PER_SLOT = 14,
     SYMBOLS_PER_HALF_SUBFRAME = 7 * (2**NUMEROLOGY),
     SYMBOLS_PER_SUBFRAME = 14 * (2**NUMEROLOGY),
     SLOTS_PER_SUBFRAME = (2**NUMEROLOGY),
     SUBFRAMES_PER_FRAME = 10,
     SUBFRAMES_PER_SECOND = 1000;

   localparam
     LONG_SYMBOL_0_IDX = calc_long_symbol_idx(0, TIME_NOT_FREQ, NUMEROLOGY ),
     LONG_SYMBOL_1_IDX = calc_long_symbol_idx(1, TIME_NOT_FREQ, NUMEROLOGY);

   reg [31:0]          pps_cnt;
   reg [2:0]           pps_state,
                       tcs_state;
   reg                 pps_d ;

   wire [15:0]         symb_duration;

   reg                 pps_edge;

   wire                pps_cnt_ok,
                       check_cnt_ok;

   wire                no_pps ;

   reg                 first_strobe;
   reg                 timer_start;
   reg [15:0]          time_cnt ;
   reg                 sync_pps_edge;
   reg [31:0]          delay_cnt,
                       check_cnt,
                       delay_range_max,
                       delay_range_min;

   reg                 one_second_strobe;

   reg                 meta_resynch,
                       reg_resynch,
                       resynch_detected;

   reg [31:0]          meta_delay_wrt_pps,
                       reg_delay_wrt_pps,
		               delay_changed;

   wire                restart_fsm;

   reg [15:0]          subframe_per_sec_idx;


   always @(posedge CLK) begin: cdc
      meta_resynch     <= RESYNCH;
      reg_resynch      <= meta_resynch;
      resynch_detected <= (~reg_resynch && meta_resynch);
      //
      meta_delay_wrt_pps <= DELAY_WRT_PPS;
      reg_delay_wrt_pps  <= meta_delay_wrt_pps;
      delay_changed      <= (reg_delay_wrt_pps != meta_delay_wrt_pps);
      //
      delay_range_max <= reg_delay_wrt_pps + TLRC_ERR;
      if (reg_delay_wrt_pps > TLRC_ERR)
         delay_range_min <= reg_delay_wrt_pps - TLRC_ERR;
      else
         delay_range_min <= 'b0;
   end // block: pps_check


   //-------------------------------------------------
   //     PPS management
   //-------------------------------------------------

   always @(posedge CLK) begin: pps_resampling
      pps_d <= PPS_IN;
   // positive edge
      pps_edge <= ~pps_d && PPS_IN;
   // negative edge
   // pps_edge <= pps_d && ~PPS_IN;
   end // block: pps_check


   always @(posedge CLK or posedge RESET) begin: pps_check
      if (RESET) begin
         pps_cnt <= 'd0;
      end
      else begin
         if (pps_edge) begin
            pps_cnt <= 'd0;
         end
         else
           pps_cnt <= pps_cnt+1;
      end
   end // block: pps_check

   assign restart_fsm       = ( delay_changed || resynch_detected);

   assign pps_cnt_ok        = ( pps_cnt < POS_ERR_TLRC &&
                                pps_cnt > NEG_ERR_TLRC );

   assign check_cnt_ok      = ( check_cnt < delay_range_max &&
                                check_cnt > delay_range_min );

   assign no_pps            = ( pps_cnt == TIME_BEFORE_NO_PPS );

   // this fsm checks the status of the input PPS
   always @(posedge CLK or posedge RESET) begin: update_status
      if (RESET) begin
         pps_state <= PPS_IDLE;
      end
      else begin
         if ( restart_fsm )
           pps_state <= PPS_IDLE;
         else begin
            case(pps_state)
              PPS_IDLE:
                if ( pps_edge )
                  pps_state <= PPS_FIRST_PPS;
                else if ( no_pps )
                  pps_state <= PPS_NO_SYNC;
              PPS_FIRST_PPS:
                if ( pps_edge & pps_cnt_ok )
                  pps_state <= PPS_SYNC;
                else if (no_pps)
                  pps_state <= PPS_NO_PPS;
                else if ( (pps_edge && ~pps_cnt_ok) )
                  pps_state <= PPS_NO_SYNC;
              PPS_SYNC:
                if ( pps_edge & pps_cnt_ok )
                  pps_state <= PPS_SYNC;
                else if (no_pps)
                  pps_state <= PPS_NO_PPS;
                else if (pps_edge && ~pps_cnt_ok)
                  pps_state <= PPS_NO_SYNC;
              PPS_NO_PPS:
                if ( pps_edge & pps_cnt_ok )
                  pps_state <= PPS_SYNC;
              PPS_NO_SYNC:
                if ( pps_edge & pps_cnt_ok )
                  pps_state <= PPS_SYNC;
                else if (no_pps)
                  pps_state <= PPS_NO_PPS;
              default :
                pps_state <= PPS_IDLE;
            endcase
         end
      end
   end // block: update_status

   always @(posedge CLK ) begin
      sync_pps_edge <= ( ( pps_state==PPS_SYNC)  &
                         ( pps_edge & pps_cnt_ok ) ) ;
   end // block: pps_check

   // this fsm checks the status of the counters wrt input PPS
   always @(posedge CLK or posedge RESET) begin: update_tcs_status
      if (RESET) begin
         // it starts the counters to gnerate a default time-frame
         tcs_state <= TCS_ASYNC_DELAY;
      end
      else begin
         if ( restart_fsm )
           tcs_state <= TCS_ASYNC_DELAY;
         else begin
            case (tcs_state)
              TCS_SYNC_DELAY:
                if ( delay_cnt==(reg_delay_wrt_pps-MIN_DELAY) )
                  tcs_state <= TCS_SYNC;
              TCS_SYNC :
                if ( sync_pps_edge )
                  tcs_state <= TCS_CHECK;
              TCS_NO_SYNC :
                if ( sync_pps_edge )
                  tcs_state <= TCS_CHECK;
              TCS_CHECK :
                if ( one_second_strobe && check_cnt_ok )
                  tcs_state <= TCS_SYNC;
                else if (one_second_strobe && ~check_cnt_ok)
                  tcs_state <= TCS_NO_SYNC;
              TCS_ASYNC_DELAY :
                if ( sync_pps_edge )
                  tcs_state <= TCS_SYNC_DELAY;
                else if ( delay_cnt==(reg_delay_wrt_pps-MIN_DELAY) )
                  tcs_state <= TCS_ASYNC_RUN;
              TCS_ASYNC_RUN :
                if ( sync_pps_edge )
                  tcs_state <= TCS_SYNC_DELAY;
              default :
                tcs_state <= TCS_ASYNC_DELAY;
            endcase
         end
      end // else: !if(RESET)
   end // block: update_tcs_status

   // PPS_CODE:
   // 000 : reset
   // 001 : PPS_SYNC    TCS_SYNC
   // 010 : PPS_SYNC    TCS_NO_SYNC
   // 011 : -
   // 100 : PPS_NO_SYNC
   // 101 : NO_PPS
   // 110 : -
   // 111 : -
   always @(posedge CLK or posedge RESET) begin: update_outputs
      if (RESET) begin
         PPS_CODE <= 'b0;
      end
      else begin
         if (pps_state==PPS_SYNC)
           if (tcs_state==TCS_SYNC)
             PPS_CODE <= 'b001;
           else if (tcs_state == TCS_NO_SYNC)
             PPS_CODE <= 'b010;
           else
             PPS_CODE <= PPS_CODE;
         else if (pps_state==PPS_NO_SYNC)
           PPS_CODE <= 'b100;
         else if (pps_state==PPS_NO_PPS)
           PPS_CODE <= 'b101;
         else
           PPS_CODE <= PPS_CODE;
      end
   end // block: update_outputs

   //-------------------------------------------------
   //     Counters
   //-------------------------------------------------

   always @(posedge CLK or posedge RESET) begin: delay_cnt_proc
      if (RESET)
        delay_cnt <= 'd0;
      else
        if (restart_fsm)
          delay_cnt <= 'd0;
        else if ( (tcs_state == TCS_SYNC_DELAY) ||
                  (tcs_state == TCS_ASYNC_DELAY) )
          delay_cnt <= delay_cnt+1;
        else
          delay_cnt <= 'd1;
   end // block: delay_proc

   always @(posedge CLK or posedge RESET) begin: check_cnt_proc
      if (RESET)
        check_cnt <= 'd0;
      else
        if (tcs_state == TCS_CHECK)
          check_cnt <= check_cnt+1;
        else
          check_cnt <= 'd1;
   end // block: delay_proc

   always @(posedge CLK or posedge RESET) begin: timer_start_proc
      if (RESET) begin
         first_strobe <= 'b0;
         timer_start <= 'd0;
      end
      else begin
         if ( ( (tcs_state == TCS_SYNC_DELAY) ||
                (tcs_state == TCS_ASYNC_DELAY) ) &&
              ( delay_cnt==(reg_delay_wrt_pps-MIN_DELAY) ) )  begin
            first_strobe <= 'b1;
         end
         else begin
            first_strobe <= 'b0;
         end
         timer_start <= first_strobe;
      end // else: !if(RESET)
   end

   assign symb_duration = ( (SYMBOL_PER_SF_IDX == LONG_SYMBOL_0_IDX) ||
                            (SYMBOL_PER_SF_IDX == LONG_SYMBOL_1_IDX) ) ?
                          SYMB_LONG_DURATION :
                          SYMB_SHORT_DURATION ;

   always @(posedge CLK or posedge RESET) begin: strobes_proc
      if (RESET) begin
         SYMBOL_STROBE <= 'b0;
         SLOT_STROBE <= 'b0;
         SUBFRAME_STROBE <= 'b0;
         FRAME_STROBE <= 'b0;
         one_second_strobe <= 'b0;
      end
      else begin
         if (first_strobe) begin
            SYMBOL_STROBE     <= 'b1;
            SLOT_STROBE       <= 'b1;
            SUBFRAME_STROBE   <= 'b1;
            FRAME_STROBE      <= 'b1;
            one_second_strobe <= 'b1;
         end
         else begin
            if (time_cnt == (symb_duration-2)) begin
               SYMBOL_STROBE <= 'b1;
               if (SYMBOL_PER_SLOT_IDX == SYMBOLS_PER_SLOT-1)
                 SLOT_STROBE <= 'b1;
               else
                 SLOT_STROBE <= 'b0;
               if (SYMBOL_PER_SF_IDX == SYMBOLS_PER_SUBFRAME-1) begin
                  SUBFRAME_STROBE <= 'b1;
                  if (SUBFRAME_IDX == SUBFRAMES_PER_FRAME-1)
                    FRAME_STROBE <= 'b1;
                  else
                    FRAME_STROBE <= 'b0;
                  if (subframe_per_sec_idx == SUBFRAMES_PER_SECOND-1)
                    one_second_strobe <= 'b1;
                  else
                    one_second_strobe <= 'b0;
               end
               else begin
                  SUBFRAME_STROBE <= 'b0;
                  FRAME_STROBE <= 'b0;
                  one_second_strobe <= 'b0;
               end
            end
            else begin
               SYMBOL_STROBE <= 'b0;
               SLOT_STROBE <= 'b0;
               SUBFRAME_STROBE <= 'b0;
               FRAME_STROBE <= 'b0;
               one_second_strobe <= 'b0;
            end
         end
      end //else: if (RESET)
   end // block: symb_per_slot_proc

   always @(posedge CLK or posedge RESET) begin: symb_per_subframe_proc
      if (RESET) begin
         time_cnt <= 'd0;
         SYMBOL_PER_SF_IDX <= 'b0;
      end
      else begin
         if (timer_start) begin
            time_cnt <= 'd0;
            SYMBOL_PER_SF_IDX <= 'b0;
         end
         else begin
            if (SYMBOL_STROBE) begin
               time_cnt <= 'd0;
               if (SYMBOL_PER_SF_IDX==(SYMBOLS_PER_SUBFRAME-1))
                 SYMBOL_PER_SF_IDX <= 'd0;
               else
                 SYMBOL_PER_SF_IDX <= SYMBOL_PER_SF_IDX+1;
            end
            else begin
               time_cnt <= time_cnt+1;
               SYMBOL_PER_SF_IDX <= SYMBOL_PER_SF_IDX;
            end
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: symb_per_subframe_proc

   assign SAMPLE_PER_SYMBOL_IDX = time_cnt;

   always @(posedge CLK or posedge RESET) begin: symb_proc
      if (RESET)
        SYMBOL_PER_SLOT_IDX <= 'b0;
      else begin
         if (timer_start)
           SYMBOL_PER_SLOT_IDX <= 'b0;
         else begin
            if (SYMBOL_STROBE)
              if (SYMBOL_PER_SLOT_IDX==(SYMBOLS_PER_SLOT-1))
                SYMBOL_PER_SLOT_IDX <= 'd0;
              else
                SYMBOL_PER_SLOT_IDX <= SYMBOL_PER_SLOT_IDX+1;
            else
              SYMBOL_PER_SLOT_IDX <= SYMBOL_PER_SLOT_IDX;
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: symb_per_slot_proc

   always @(posedge CLK or posedge RESET) begin: slot_proc
      if (RESET)
        SLOT_IDX <= 'b0;
      else begin
         if (timer_start)
           SLOT_IDX <= 'b0;
         else begin
            if (SLOT_STROBE) begin
               if (SLOT_IDX==(SLOTS_PER_SUBFRAME-1))
                 SLOT_IDX <= 'd0;
               else
                 SLOT_IDX <= SLOT_IDX+1;
            end
            else
              SLOT_IDX <= SLOT_IDX;
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: slot_proc

   always @(posedge CLK or posedge RESET) begin: subframe_proc
      if (RESET)
        SUBFRAME_IDX<= 'b0;
      else begin
         if (timer_start)
           SUBFRAME_IDX<= 'b0;
         else begin
            if (SUBFRAME_STROBE) begin
               if (SUBFRAME_IDX==(SUBFRAMES_PER_FRAME-1))
                 SUBFRAME_IDX <= 'b0;
               else
                 SUBFRAME_IDX <= SUBFRAME_IDX+1;
            end
            else
              SUBFRAME_IDX <= SUBFRAME_IDX;
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: subframe_proc

   always @(posedge CLK or posedge RESET) begin: subframe_per_sec_proc
      if (RESET)
        subframe_per_sec_idx<= 'b0;
      else begin
         if (timer_start)
           subframe_per_sec_idx<= 'b0;
         else begin
            if (SUBFRAME_STROBE) begin
               if (subframe_per_sec_idx==(SUBFRAMES_PER_SECOND-1))
                 subframe_per_sec_idx <= 'b0;
               else
                 subframe_per_sec_idx <= subframe_per_sec_idx+1;
            end
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: subframe_proc

   always @(posedge CLK or posedge RESET) begin: frame_proc
      if (RESET)
        FRAME_IDX<= 'b0;
      else begin
         if (timer_start)
           FRAME_IDX<= 'b0;
         else begin
            if (FRAME_STROBE)
              FRAME_IDX <= FRAME_IDX+1;
            else
              FRAME_IDX <= FRAME_IDX;
         end // else: if (timer_start)
      end //else: if (RESET)
   end // block: frame_proc


endmodule // tdd_switch_ctrl
