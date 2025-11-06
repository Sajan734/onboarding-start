/*
 * Copyright (c) 2024 Sajan Paventhan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_uwasic_onboarding_sajan_paventhan (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // system clock
    input  wire       rst_n     // active-low reset
);

  // --------------------------------------------------------------------------
  // SPI pin assignments (choose any mapping you want)
  // --------------------------------------------------------------------------
  wire spi_ncs   = ui_in[0];
  wire spi_sclk  = ui_in[1];
  wire spi_copi  = ui_in[2];
  wire spi_cipo;

  // --------------------------------------------------------------------------
  // Internal register wires connected between SPI and PWM modules
  // --------------------------------------------------------------------------
  wire [7:0] en_reg_out_7_0;
  wire [7:0] en_reg_out_15_8;
  wire [7:0] en_reg_pwm_7_0;
  wire [7:0] en_reg_pwm_15_8;
  wire [7:0] pwm_duty_cycle;

  // --------------------------------------------------------------------------
  // SPI Peripheral Module
  // --------------------------------------------------------------------------
  spi_peripheral spi_peripheral_inst (
    .clk(clk),
    .rst_n(rst_n),
    .spi_ncs_i(spi_ncs),
    .spi_sclk_i(spi_sclk),
    .spi_copi_i(spi_copi),
    .spi_cipo_o(spi_cipo),
    .en_reg_out_7_0(en_reg_out_7_0),
    .en_reg_out_15_8(en_reg_out_15_8),
    .en_reg_pwm_7_0(en_reg_pwm_7_0),
    .en_reg_pwm_15_8(en_reg_pwm_15_8),
    .pwm_duty_cycle(pwm_duty_cycle)
  );

  // --------------------------------------------------------------------------
  // PWM Peripheral Module
  // --------------------------------------------------------------------------
  pwm_peripheral pwm_peripheral_inst (
    .clk(clk),
    .rst_n(rst_n),
    .en_reg_out_7_0(en_reg_out_7_0),
    .en_reg_out_15_8(en_reg_out_15_8),
    .en_reg_pwm_7_0(en_reg_pwm_7_0),
    .en_reg_pwm_15_8(en_reg_pwm_15_8),
    .pwm_duty_cycle(pwm_duty_cycle),
    .out({uio_out, uo_out})
  );

  // --------------------------------------------------------------------------
  // I/O configuration
  // --------------------------------------------------------------------------
  assign uio_oe = 8'hFF;   // all uio_out pins as outputs
  assign uio_out[0] = spi_cipo; // SPI MISO on uio_out[0]
  assign uio_out[7:1] = 7'b0;   // unused outputs tied low

  // Prevent unused signal warnings
  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule
