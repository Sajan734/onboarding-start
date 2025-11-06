/*
 * Copyright (c) 2025
 * SPDX-License-Identifier: Apache-2.0
 *
 * SPI slave peripheral for PWM control
 * Transaction format: [R/W(1) | ADDR(7) | DATA(8)]
 * - R/W = 1: Write DATA to register ADDR
 * - R/W = 0: Read from register ADDR (DATA returned via MISO)
 */

`default_nettype none

module spi_peripheral #(
    parameter MAX_ADDRESS = 8'h04
)(
    input  wire       clk,        // system clock
    input  wire       rst_n,      // active-low reset

    // SPI interface (asynchronous to clk)
    input  wire       spi_ncs_i,  // chip select (active low)
    input  wire       spi_sclk_i, // SPI clock
    input  wire       spi_copi_i, // MOSI
    output wire       spi_cipo_o, // MISO

    // Register outputs
    output reg [7:0]  en_reg_out_7_0,
    output reg [7:0]  en_reg_out_15_8,
    output reg [7:0]  en_reg_pwm_7_0,
    output reg [7:0]  en_reg_pwm_15_8,
    output reg [7:0]  pwm_duty_cycle
);

  // --------------------------------------------------------------------------
  // Synchronizers for asynchronous SPI inputs
  // --------------------------------------------------------------------------
  reg [2:0] ncs_sync, sclk_sync, copi_sync;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ncs_sync  <= 3'b111;
      sclk_sync <= 3'b000;
      copi_sync <= 3'b000;
    end else begin
      ncs_sync  <= {ncs_sync[1:0], spi_ncs_i};
      sclk_sync <= {sclk_sync[1:0], spi_sclk_i};
      copi_sync <= {copi_sync[1:0], spi_copi_i};
    end
  end

  wire ncs_syncd  = ncs_sync[2];
  wire sclk_syncd = sclk_sync[2];
  wire copi_syncd = copi_sync[2];

  // --------------------------------------------------------------------------
  // Edge detection
  // --------------------------------------------------------------------------
  reg sclk_prev, ncs_prev;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_prev <= 0;
      ncs_prev  <= 1;
    end else begin
      sclk_prev <= sclk_syncd;
      ncs_prev  <= ncs_syncd;
    end
  end

  wire sclk_rising  = (sclk_syncd & ~sclk_prev);
  wire sclk_falling = (~sclk_syncd & sclk_prev);
  wire ncs_rising   = (ncs_syncd & ~ncs_prev);
  wire ncs_falling  = (~ncs_syncd & ncs_prev);

  // --------------------------------------------------------------------------
  // SPI data capture and transaction handling
  // --------------------------------------------------------------------------
  reg [15:0] shift_in;
  reg [7:0]  miso_shift;
  reg [4:0]  bit_count;
  reg        miso_out;

  assign spi_cipo_o = miso_out;

  reg transaction_valid;
  reg transaction_rw;
  reg [6:0] transaction_addr;
  reg [7:0] transaction_data;

  // --------------------------------------------------------------------------
  // Main SPI logic
  // --------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_in          <= 0;
      bit_count         <= 0;
      miso_shift        <= 0;
      miso_out          <= 0;
      transaction_valid <= 0;
      transaction_rw    <= 0;
      transaction_addr  <= 0;
      transaction_data  <= 0;
      en_reg_out_7_0    <= 0;
      en_reg_out_15_8   <= 0;
      en_reg_pwm_7_0    <= 0;
      en_reg_pwm_15_8   <= 0;
      pwm_duty_cycle    <= 0;
    end else begin
      // Begin transaction
      if (ncs_falling) begin
        bit_count         <= 0;
        shift_in          <= 0;
        transaction_valid <= 0;
      end

      // Shift in data (MSB first)
      if (!ncs_syncd && sclk_rising) begin
        shift_in  <= {shift_in[14:0], copi_syncd};
        bit_count <= bit_count + 1;

        // Prepare MISO data during data phase
        if (bit_count == 7) begin
          // Decode header
          reg [15:0] tmp;
          tmp = {shift_in[14:0], copi_syncd};
          transaction_rw   <= tmp[15];
          transaction_addr <= tmp[14:8];

          if (tmp[15] == 1'b0) begin
            case (tmp[14:8])
              7'd0: miso_shift <= en_reg_out_7_0;
              7'd1: miso_shift <= en_reg_out_15_8;
              7'd2: miso_shift <= en_reg_pwm_7_0;
              7'd3: miso_shift <= en_reg_pwm_15_8;
              7'd4: miso_shift <= pwm_duty_cycle;
              default: miso_shift <= 8'h00;
            endcase
          end else begin
            miso_shift <= 8'h00;
          end
        end
      end

      // Shift out data on falling edge
      if (!ncs_syncd && sclk_falling) begin
        if (bit_count >= 8)
          {miso_shift, miso_out} <= {miso_shift[6:0], 1'b0, miso_shift[7]};
        else
          miso_out <= 0;
      end

      // Transaction end
      if (ncs_rising && bit_count == 16) begin
        transaction_rw    <= shift_in[15];
        transaction_addr  <= shift_in[14:8];
        transaction_data  <= shift_in[7:0];
        transaction_valid <= (shift_in[14:8] <= MAX_ADDRESS);
      end

      // Apply transaction (write)
      if (transaction_valid && transaction_rw) begin
        case (transaction_addr)
          7'd0: en_reg_out_7_0  <= transaction_data;
          7'd1: en_reg_out_15_8 <= transaction_data;
          7'd2: en_reg_pwm_7_0  <= transaction_data;
          7'd3: en_reg_pwm_15_8 <= transaction_data;
          7'd4: pwm_duty_cycle  <= transaction_data;
        endcase
        transaction_valid <= 0;
      end
    end
  end

endmodule
