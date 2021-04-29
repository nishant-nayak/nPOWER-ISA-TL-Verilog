\m4_TLV_version 1d: tl-x.org
\SV
   //////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Create Date : 17:15:26 24/04/2021
   // Team Members: Nishant N Nayak, Shreya Shaji Namath, Addhyan Malhotra, Aditya Santhosh
   // Roll Number : 191CS141		  , 191CS249			  , 191CS202		  , 191CS105
   //
   // Project Name: nPOWER ISA
   // Description : nPOWER ISA is a (very small) subset of the POWER ISA v3.0. It is a 64bit ISA. 
   //               All registers are 64 bits (numbered 0 (MSB) to 63 (LSB)).
   //
   //////////////////////////////////////////////////////////////////////////////////////////////

   // Modules imported for register file, data memory and instruction memory
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   //m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/addhyanmalhotra/nPOWER-ISA-TL-Verilog/master/mem.tlv?token=ANLMHETVEUDGJTKI4MPTDTDASIEM2'])
   // m4_include_lib(['https://gist.githubusercontent.com/shivampotdar/4513b1659da026a9da2e8a00613b065c/raw/90ff045ffb6e2194ab351935525165aacb8cda90/tlv_memories.tlv'])
\SV
   // Top level module instantiation
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
  /* verilator lint_off LITENDIAN */
\TLV
   |cpu
      @0
         $reset = *reset;
         // Program Counter
         // TO-DO Add branch logic
         $next_pc[31:0] = $pc + 4;
         $pc[31:0] = >>1$next_pc;
         // Instruction Fetch
         // add r6, r1, r2 => final value in r6 should be 3
         $instr[0:31] = {6'd31, 5'd6, 5'd1, 5'd2, 10'd266, 1'b0} ;

      @1
         // Instruction Decode
         
         // Primary OP-Code
         $po[5:0] = $instr[0:5];
         
         // Extract Extended OP-Code
         $xo[9:0] = $instr[21:30];
         
         // Determine instruction Type
         $is_d_instr = $po == 6'b00111x ||
                     $po == 6'b0110X0 ||
                     $po == 6'b011100 ||
                     $po == 6'b011010 ||
                     $po == 6'b001011;
         $is_ds_instr = ($po == 6'b111x10);
         $is_i_instr  = ($po == 6'b010010);
         $is_x_instr  = ($po == 31) && ($xo != 266 && $xo != 40);
         $is_xo_instr = ($po == 31) && ($xo == 266 || $xo == 40);
         
         // Extract Register Indicies
         $rs_rt[4:0] = $instr[6:10];
         $ra[4:0] = $instr[11:15];
         $rb[4:0] = $instr[16:20];
         
         // Extract Immediate Fields
         $si[63:0] = { {48{$instr[16]}}, $instr[16:31] };
         $ui[63:0] = { 48'b0, $instr[16:31] };
         
         // Check whether the given fields are valid 
         $rs_rt_valid = !($is_i_instr);
         $ra_valid = !($is_i_instr);
         $rb_valid = ($is_x_instr || $is_xo_instr);
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
         // Determining the correct source and destination regsiters based on the instruction
         $rd[4:0] = ($is_xo_instr || $is_addi || $is_addis || $is_ld) ? $rs_rt :
                  (($is_x_instr && !($is_cmp)) || $is_andi || $is_ori || $is_xori) ? $ra :
                  -1;
         $rs1[4:0] = ($is_xo_instr || $is_ds_instr || $is_addi || $is_addis || $is_cmp || $is_cmpi) ? $ra :
                     (($is_x_instr && !($is_cmp)) || $is_andi || $is_ori || $is_xori) ? $rs_rt :
                     0;

      @2
         // ALU Execution
         /*
         // SLTU & SLTI (set if less than, unsigned)
         $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
         $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
         // SRA & SRAI (shift right, arithmetic)
         // sign-extended src1
         $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
         // 64-bit sign-extended result
         $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
         $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
         */
         // ALU
         
         $result[63:0] = $is_add   ? /top>>0$src1_value + /top>>0$src2_value :
                        $is_addi  ? (($rs1 == 0) ? 0 : /top>>0$src1_value) + $si :
                        $is_addis ? (($rs1 == 0) ? 0 : /top>>0$src1_value) + {$si[47:0], 16'b0} :
                        $is_and   ? /top>>0$src1_value & /top>>0$src2_value :
                        $is_andi  ? /top>>0$src1_value & $ui :
                        $is_extsw ? { {32{/top>>0$src1_value[31]}}, /top>>0$src1_value[31:0] } :
                        $is_nand  ? ~(/top>>0$src1_value & /top>>0$src2_value) :
                        $is_or    ? /top>>0$src1_value | /top>>0$src2_value :
                        $is_ori   ? /top>>0$src1_value | $ui :
                        $is_subf  ? /top>>0$src2_value - /top>>0$src1_value :
                        $is_xor   ? /top>>0$src1_value ^ /top>>0$src2_value :
                        $is_xori  ? /top>>0$src1_value ^ $ui :
                        $is_ld    ? (($rs1 == 0) ? 0 : /top>>0$src1_value) + { $si[62:0], 1'b0 } :
                        $is_std   ? (($rs1 == 0) ? 0 : /top>>0$src1_value) + { $si[62:0], 1'b0 } :
                        //$is_b     = $po == 18;
                        //$is_cmp   = $po == 31 && $xo == 0;
                        //$is_cmpi  = $po == 11;
                        32'b0;
   /*
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
   */
   `BOGUS_USE(|cpu>>1$is_b |cpu>>1$xo_valid);
   // Assert these to end simulation (before Makerchip cycle limit).
   //$result[63:0] = 64'b1;
   *failed = 1'b0; //*cyc_cnt > 70; // To change to MAX_CYC_CNT
   *passed = /xreg[6]$value == 3;
   
   m4+rf(32, 64, |cpu>>0$reset, (|cpu>>1$rd >=0 && |cpu>>1$rd < 32) ? |cpu>>1$rs_rt_valid : 1'b0, |cpu>>1$rd, |cpu>>1$is_ld ? /top>>0$ld_data : |cpu>>2$result, |cpu>>1$ra_valid, |cpu>>1$rs1, $src1_value, |cpu>>1$rb_valid, |cpu>>1$rb, $src2_value)
   m4+dmem(32, 64, |cpu>>0$reset, |cpu>>2$result[6:2], |cpu>>1$is_std, $src2_value, |cpu>>1$is_ld, $ld_data)
\SV
   endmodule
