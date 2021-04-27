\m4_TLV_version 1d: tl-x.org
\SV
   //////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Create Date: 17:15:26 24/04/2021
   // Student Name: Nishant N Nayak
   // Roll Number: 191CS141
   //
   // Project Name: nPOWER ISA
   // Description: nPOWER ISA is a (very small) subset of the POWER ISA v3.0. It is a 64bit ISA. 
   //              All registers are 64 bits (numbered 0 (MSB) to 63 (LSB)).
   //
   //////////////////////////////////////////////////////////////////////////////////////////////

   // Modules imported for register file, data memory, testbench and visualization
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   // m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])
   m4_include_lib(['/mem.tlv'])
	
   // Macro instantiation for instruction memory
   m4_test_prog()

\SV
   // Top level module instantiation
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   $reset = *reset;

   // Program Counter 
   $next_pc[31:0] = $reset ? 32'b0 :
                    $taken_br || $is_jal ? $br_tgt_br :
                    $is_jalr ? $jalr_tgt_pc :
                    $pc + 4;
   $pc[31:0] = >>1$next_pc;

   // Instruction Fetch
   `READONLY_MEM($pc, $$instr[0:31])
   
   // Instruction Decode
   $po[0:5] = $instr[0:5];
   $rs_rt[0:4] = $instr[6:10];
   $ra[0:4] = $instr[11:15];
   $rb[0:4] = $instr[16:20];
   $xo[0:9] = $instr[21:30];
   
   $is_d_instr = $po ==? 6'b00111x || 
                 $po ==? 6'b011x00 ||
                 $po == 6'b011010 ||
                 $po == 6'b001011;
   $is_ds_instr = $po ==? 6'b111x10;
   $is_i_instr = $po == 6'b010010;
   
   // Extract instruction fields
   // $imm[0:63] = $is_d_instr ?  :
   //             $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
   //             $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25],
   //                              $instr[11:8], 1'b0 } :
   //             $is_u_instr ? { $instr[31], $instr[30:12], 12'b0 } :
   //             $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20],
   //                              $instr[30:21], 1'b0 } :
   //                           32'b0;
   
   // Check whether the given fields are valid 
   $rs_rt_valid = !$is_i_instr;
   $ra_valid = !$is_i_instr;
   $rb_valid = !($is_i_instr || $is_d_instr || $is_ds_instr);
   $xo_valid = !($is_i_instr || $is_d_instr);
   
   // Determining the exact instruction
   $is_add   = $po == 31 && $xo == 266;
   $is_addi  = $po == 14;
   $is_addis = $po == 15;
   $is_and   = $po == 31 && $xo == 28;
   $is_andi  = $po == 28;
   $is_extsw = $po == 31 && $xo == 986;
   $is_nand  = $po == 31 && $xo == 476;
   $is_or    = $po == 31 && $xo == 444;
   $is_ori   = $po == 24;
   $is_subf  = $po == 31 && $xo == 40;
   $is_xor   = $po == 31 && $xo == 316;
   $is_xori  = $po == 26;
   $is_ld    = $po == 58 && $xo == 0;
   $is_std   = $po == 62 && $xo == 0;
   $is_b     = $po == 18;
   $is_cmp   = $po == 31 && $xo == 0;
   $is_cmpi  = $po == 11;

   // ALU Execution
   // SLTU & SLTI (set if less than, unsigned)
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   // SRA & SRAI (shift right, arithmetic)
   // sign-extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
   // 64-bit sign-extended result
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   // ALU
   $result[31:0] = $is_andi  ? $src1_value & $imm :
                   $is_ori   ? $src1_value | $imm :
                   $is_xori  ? $src1_value ^ $imm :
                   $is_addi | $is_load | $is_store ? $src1_value + $imm :
                   $is_slli  ? $src1_value << $imm[5:0] :
                   $is_srli  ? $src1_value >> $imm[5:0] :
                   $is_and   ? $src1_value & $src2_value :
                   $is_or    ? $src1_value | $src2_value :
                   $is_xor   ? $src1_value ^ $src2_value :
                   $is_add   ? $src1_value + $src2_value :
                   $is_sub   ? $src1_value - $src2_value :
                   $is_sll   ? $src1_value << $src2_value[4:0] :
                   $is_srl   ? $src1_value >> $src2_value[4:0] :
                   $is_sltu  ? $sltu_rslt :
                   $is_sltiu ? $sltiu_rslt :
                   $is_lui   ? {$imm[31:12], 12'b0} :
                   $is_auipc ? $pc + $imm :
                   $is_jal   ? $pc + 4 :
                   $is_jalr  ? $pc + 4 :
                   $is_slt   ? (($src1_value[31] == $src2_value[31]) ?
                                  $sltu_rslt :
                                  {31'b0, $src1_value[31]}) :
                   $is_slti  ? (($src1_value[31] == $imm[31]) ?
                                  $sltiu_rslt :
                                  {31'b0, $src1_value[31]}) :
                   $is_sra   ? $sra_rslt[31:0] :
                   $is_srai  ? $srai_rslt[31:0] :
                   32'b0;

   // Branch logic
   $taken_br = $is_beq ? $src1_value == $src2_value :
               $is_bne ? $src1_value != $src2_value :
               $is_blt ? ($src1_value < $src2_value) ^
                         ($src1_value[31] != $src2_value[31]) :
               $is_bge ? ($src1_value >= $src2_value) ^
                         ($src1_value[31] != $src2_value[31]) :
               $is_bltu ? $src1_value  < $src2_value :
               $is_bgeu ? $src1_value >= $src2_value :
               1'b0;
   $br_tgt_br[31:0] = $pc + $imm;
   $jalr_tgt_pc[31:0] = $src1_value + $imm;

   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > 70; // To change to MAX_CYC_CNT

   m4+rf(32, 32, $reset, $rd != 5'b00000 ? $rd_valid : 1'b0, $rd, $is_load ? $ld_data : $result, $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
   m4+dmem(32, 32, $reset, $result[6:2], $is_store, $src2_value, $is_load, $ld_data)
   m4+cpu_viz()
\SV
   endmodule