/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab10: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

/**
 * This section contains the definition of the class and the instantiation of the object.
 *  * 
 * The always_ff blocks update the object based on the values of valid signals.
 * When valid signal is true, the corresponding property is updated with the value of inf.D
 */

class Formula_and_mode;
    Formula_Type f_type;
    Mode f_mode;
endclass

Formula_and_mode fm_info = new();

always_ff @( posedge clk ) begin : fm_info_FF
    if(inf.formula_valid)   fm_info.f_type = inf.D.d_formula[0];
    else                    fm_info.f_type = fm_info.f_type;

    if(inf.mode_valid)  fm_info.f_mode = inf.D.d_mode[0];
    else                fm_info.f_mode = fm_info.f_mode;
end

Action act_info;

always_ff @( posedge clk ) begin : act_info_FF
    if(inf.sel_action_valid)    act_info = inf.D.d_act[0];
    else                        act_info = act_info;
end
// ============================================================================ //
//                                 VARIABLES                                    //
// ============================================================================ //

// ============================================================================ //
//                                 COVERAGE                                     //
// ============================================================================ //
covergroup COV_SPEC1 @ (posedge clk iff(inf.formula_valid));
    option.name = "formula_coverage";
    option.at_least = 150;
    option.per_instance = 1;

    coverpoint fm_info.f_type {
        bins formula_bins [] = {[Formula_A:Formula_H]};
    }
endgroup

covergroup COV_SPEC2 @ (posedge clk iff(inf.mode_valid));
    option.name = "mode_coverage";
    option.at_least = 150;
    option.per_instance = 1;

    coverpoint fm_info.f_mode {
        bins mode_bins [] = {[Insensitive:Sensitive]};
    }
endgroup

covergroup COV_SPEC3 @ (posedge clk iff(inf.mode_valid));
    option.name = "formula_mode_coverage";
    option.at_least = 150;
    option.per_instance = 1;

    coverpoint fm_info.f_type {
        bins formula_bins [] = {[Formula_A:Formula_H]};
    }

    coverpoint fm_info.f_mode {
        bins mode_bins [] = {[Insensitive:Sensitive]};
    }

    cross fm_info.f_type, fm_info.f_mode;
endgroup

covergroup COV_SPEC4 @ (inf.out_valid);
    option.name = "warn_coverage";
    option.at_least = 50;
    option.per_instance = 1;

    coverpoint inf.warn_msg {
        bins warn_bins [] = {[No_Warn:Data_Warn]};
    }
endgroup

covergroup COV_SPEC5 @ (posedge clk iff(inf.sel_action_valid));
    option.name = "action_tran_coverage";
    option.at_least = 300;
    option.per_instance = 1;

    coverpoint inf.D.d_act[0] {
        bins act_bins [] = ([Index_Check:Check_Valid_Date] => [Index_Check:Check_Valid_Date]);
    }
endgroup

covergroup COV_SPEC6 @ (inf.index_valid iff(act_info == Update));
    option.name = "update_coverage";
    option.auto_bin_max = 32;
    option.at_least = 1;
    option.per_instance = 1;

    coverpoint inf.D.d_index[0];
endgroup

// Initialization
COV_SPEC1 cov1 = new();
COV_SPEC2 cov2 = new();
COV_SPEC3 cov3 = new();
COV_SPEC4 cov4 = new();
COV_SPEC5 cov5 = new();
COV_SPEC6 cov6 = new();

// ============================================================================ //
//                                 ASERTION                                     //
// ============================================================================ //
// SPEC1
property p_spec1;
    @(posedge inf.rst_n) 1|-> @(posedge clk) (inf.out_valid === 0 && inf.warn_msg  === 0 && inf.complete  === 0 && inf.AR_VALID === 0 && inf.AR_ADDR  === 0 && inf.R_READY  === 0 && inf.AW_VALID === 0 && inf.AW_ADDR  === 0 && inf.W_VALID  === 0 && inf.W_DATA   === 0 && inf.B_READY  === 0);
endproperty

// SPEC2
property p_spec2_icheck;
    @(posedge clk) (act_info === Index_Check) && inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid |-> ##[1:999] inf.out_valid;
endproperty
property p_spec2_update;
    @(posedge clk) (act_info === Update) && inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid |-> ##[1:999] inf.out_valid;
endproperty
property p_spec2_dcheck;
    @(posedge clk) (act_info === Check_Valid_Date) && inf.date_valid ##[1:4] inf.data_no_valid |-> ##[1:999] inf.out_valid;
endproperty

// SPEC3
property p_spec3;
    @(negedge clk) inf.complete |-> (inf.warn_msg === No_Warn);
endproperty

// SPEC4
property p_spec4_icheck;
    @(posedge clk) inf.sel_action_valid && (inf.D.d_act[0] === Index_Check) |-> ##[1:4] inf.formula_valid ##[1:4] inf.mode_valid ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid;
endproperty
property p_spec4_update;
    @(posedge clk) inf.sel_action_valid && (inf.D.d_act[0] === Update) |-> ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid;
endproperty
property p_spec4_dcheck;
    @(posedge clk) inf.sel_action_valid && (inf.D.d_act[0] === Check_Valid_Date) |-> ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid;
endproperty

// SPEC5
property p_spec5_action;
    @(posedge clk) inf.sel_action_valid |-> !(inf.formula_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.index_valid);
endproperty
property p_spec5_formula;
    @(posedge clk) inf.formula_valid |-> !(inf.sel_action_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.index_valid);
endproperty
property p_spec5_mode;
    @(posedge clk) inf.mode_valid |-> !(inf.formula_valid || inf.sel_action_valid || inf.date_valid || inf.data_no_valid || inf.index_valid);
endproperty
property p_spec5_data;
    @(posedge clk) inf.date_valid |-> !(inf.formula_valid || inf.mode_valid || inf.sel_action_valid || inf.data_no_valid || inf.index_valid);
endproperty
property p_spec5_data_no;
    @(posedge clk) inf.data_no_valid |-> !(inf.formula_valid || inf.mode_valid || inf.date_valid || inf.sel_action_valid || inf.index_valid);
endproperty
property p_spec5_index;
    @(posedge clk) inf.index_valid |-> !(inf.formula_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.sel_action_valid);
endproperty

// SPEC6
property p_spec6;
    @(posedge clk) inf.out_valid |=> !inf.out_valid;
endproperty

// SPEC7
property p_spec7;
    @(posedge clk) inf.out_valid |=> !inf.out_valid ##[0:3] inf.sel_action_valid;
endproperty

// SPEC8
property p_spec8_m;
    @(posedge clk) inf.date_valid |-> (inf.D.d_date[0].M inside {[1:12]});
endproperty
property p_spec8_28;
    @(posedge clk) inf.date_valid && (inf.D.d_date[0].M === 2) |-> (inf.D.d_date[0].D inside {[1:28]});
endproperty
property p_spec8_30;
    @(posedge clk) inf.date_valid && (inf.D.d_date[0].M === 4 || inf.D.d_date[0].M === 6 || inf.D.d_date[0].M === 9 || inf.D.d_date[0].M === 11) |-> (inf.D.d_date[0].D inside {[1:30]});
endproperty
property p_spec8_31;
    @(posedge clk) inf.date_valid && (inf.D.d_date[0].M === 1 || inf.D.d_date[0].M === 3 || inf.D.d_date[0].M === 5 || inf.D.d_date[0].M === 7 || inf.D.d_date[0].M === 8 || inf.D.d_date[0].M === 10 || inf.D.d_date[0].M === 12) |-> (inf.D.d_date[0].D inside {[1:31]});
endproperty

// SPEC9
property p_spec9_r;
    @(posedge clk) inf.AR_VALID |-> !inf.AW_VALID;
endproperty
property p_spec9_w;
    @(posedge clk) inf.AW_VALID |-> !inf.AR_VALID;
endproperty

// display msg
a_spec1 : assert property (p_spec1)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 1 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec2_1: assert property(p_spec2_icheck and p_spec2_update and p_spec2_dcheck) 
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 2 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec3 : assert property (p_spec3)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 3 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec4 : assert property (p_spec4_icheck and p_spec4_update and p_spec4_dcheck)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 4 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec5 : assert property (p_spec5_action and p_spec5_formula and p_spec5_mode and p_spec5_data and p_spec5_data_no and p_spec5_index)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 5 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec6 : assert property (p_spec6)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 6 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec7 : assert property (p_spec7)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 7 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec8 : assert property (p_spec8_m and p_spec8_28 and p_spec8_30 and p_spec8_31)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 8 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end

a_spec9 : assert property (p_spec9_r and p_spec9_w)
else begin
    $display("************************************************");
    $display("*                                              *");
    $display("*           Assertion 9 is violated            *");
    $display("*                                              *");
    $display("************************************************");
    $fatal; 
end


endmodule