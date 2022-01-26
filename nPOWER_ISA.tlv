\m4_TLV_version 1d: tl-x.org
\SV
   //////////////////////////////////////////////////////////////////////////////////////////
   //
   // Create Date : 17:15:26 24/04/2021
   // Team Members: Nishant N Nayak, Shreya Shaji Namath, Addhyan Malhotra, Aditya Santhosh
   // Roll Number : 191CS141       , 191CS249           , 191CS202        , 191CS105
   //
   // Project Name: nPOWER ISA
   // Description : nPOWER ISA is a (very small) subset of the POWER ISA v3.0. It is a 64bit ISA.
   //               All registers are 64 bits (numbered 0 (MSB) to 63 (LSB)).
   //
   //////////////////////////////////////////////////////////////////////////////////////////

   // Modules imported for register file, data memory and instruction memory
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])

//-------------------DECLARATIONS-------------------------//

// Note - Adopted from - https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/blob/main/lib/risc-v_shell_lib.tlv#L123-L236
// I have removed the Viz part of this code for simplicity. You can add it back from the above source if you are building up on the RISC-V core itself.

// Instruction memory in |cpu at the given stage.
\TLV imem(@_stage)
   // Instruction Memory containing program defined by m4_asm(...) instantiations.
   @_stage
      \SV_plus
         // The program in an instruction memory.
         parameter N = 8;
         logic [31:0] instrs [0:N-1];
         // RISC-V has an inline assembler which automatically fills this SV array. For POWER, you can do this manually by changing the assignment below. Note that it is not mandatory to split instruction bitfields like the example below (you can write 32'b00000000000100110011 instead of {7'b0000000, 5'd0, 5'd0, 3'b000, 5'd10, 7'b0110011} if you prefer.
         assign instrs = '{
            // addi r9, r0, 9 //3920_0009
            {6'd14, 5'd9, 5'd0, 16'd9},
            // add r10, r0, r0 // 7d40_0214
            {6'd31, 5'd10, 5'd0, 5'd0, 10'd266, 1'd0},
            // add r10, r10 , r9 // 7d4a_4a14
            {6'd31, 5'd10, 5'd10, 5'd9, 10'd266, 1'd0},
            // subf r9, r1, r9 // 7d21_4850
            {6'd31, 5'd9, 5'd1, 5'd9, 10'd40, 1'd0},
            // cmp r9, r0 // 7c09_0000
            {6'd31, 5'd0, 5'd9, 5'd0, 11'd0},
            // bc (greater than) r9, r0, -12 (relative target address) // 4c1c_ffd0
            {6'd19, 5'd0, 5'd28, 14'b11111111110100, 2'd0},
            // std r10, 0(r0 // f280_0000
            {6'd62, 5'd10, 5'd0, 14'd0, 2'd0},
            // ld r11, 0(r0) // d2c0_0000
            {6'd58, 5'd11, 5'd0, 14'd0, 2'd0}
         };
      /imem[N-1:0]
         $ins[31:0] = *instrs\[#imem\];
      ?$imem_rd_en
         $imem_rd_data[31:0] = /imem[$imem_rd_addr]$ins;

// This is not exactly a module in Verilog sense but just a macro definition which does text replacement based on where you declare m4+rf. Refer to the edX course for usage of the rf and dmem macros.
// Register File
\TLV rf(_entries, _width, $_reset, $_port1_en, $_port1_index, $_port1_data, $_port2_en, $_port2_index, $_port2_data, $_port3_en, $_port3_index, $_port3_data)
   $rf1_wr_en = m4_argn(4, $@);
   $rf1_wr_index[\$clog2(_entries)-1:0]  = m4_argn(5, $@);
   $rf1_wr_data[_width-1:0] = m4_argn(6, $@);

   $rf1_rd_en1 = m4_argn(7, $@);
   $rf1_rd_index1[\$clog2(_entries)-1:0] = m4_argn(8, $@);

   $rf1_rd_en2 = m4_argn(10, $@);
   $rf1_rd_index2[\$clog2(_entries)-1:0] = m4_argn(11, $@);

   /xreg[m4_eval(_entries-1):0]
      $wr = /top$rf1_wr_en && (/top$rf1_wr_index == #xreg);
      <<1$value[_width-1:0] = /top$_reset ? #xreg              :
                                 $wr      ? /top$rf1_wr_data :
                                            $RETAIN;

   $_port2_data[_width-1:0]  =  $rf1_rd_en1 ? /xreg[$rf1_rd_index1]$value : 'X;
   $_port3_data[_width-1:0]  =  $rf1_rd_en2 ? /xreg[$rf1_rd_index2]$value : 'X;


// Data Memory
\TLV dmem(_entries, _width, $_reset, $_addr, $_port1_en, $_port1_data, $_port2_en, $_port2_data)
   // Allow expressions for most inputs, so define input signals.
   $dmem1_wr_en = $_port1_en;
   $dmem1_addr[\$clog2(_entries)-1:0] = $_addr;
   $dmem1_wr_data[_width-1:0] = $_port1_data;

   $dmem1_rd_en = $_port2_en;

   /dmem[m4_eval(_entries-1):0]
      $wr = /top$dmem1_wr_en && (/top$dmem1_addr == #dmem);
      <<1$value[_width-1:0] = /top$_reset ? 0                 :
                              $wr         ? /top$dmem1_wr_data :
                                            $RETAIN;

   $_port2_data[_width-1:0] = $dmem1_rd_en ? /dmem[$dmem1_addr]$value : 'X;
\SV
   // Top level module instantiation
   m4_makerchip_module
\TLV
   |cpu
      @0 // Instruction Fetch (IF) Stage
         $reset = *reset;
         
         $imem_rd_en = 1;
         
         // PC Value depends on the type of previous instruction
         $pc[63:0] = >>1$reset ? 32'b0 :
                     (>>2$is_b || >>2$is_bc) ? >>2$br_tgt :
                     >>1$pc4;
         
         // PC is divided by 4 to fetch the next 4-byte instruction
         $imem_rd_addr[63:0] = {2'b0, $pc[63:2]};

         // Instruction Fetch
         $instr[31:0] = $imem_rd_data;
         
      @1 // Instruction Decode (ID) Stage
         // Increment PC+4 (NIA)
         $pc4[63:0] = $pc + 64'd4;

         // Extract Primary OP-Code
         $po[5:0] = $instr[31:26];

         // Extract Extended OP-Code
         $xo[9:0] = $instr[10:1];

         // Extract Register Indices
         $rs_rt[4:0] = $instr[25:21];
         $ra[4:0] = $instr[20:16];
         $rb[4:0] = $instr[15:11];
         $bi[4:0] = $ra;

         // Extract Immediate Fields
         $si[63:0] = { {48{$instr[15]}}, $instr[15:0] };
         $ui[63:0] = { 48'b0, $instr[15:0] };
         $li[63:0] = { {40{$instr[25]}}, $instr[25:2], 2'b00 };
         $bd[63:0] = { {50{$instr[15]}}, $instr[15:2]};

         // Determine Instruction Type
         $is_d_instr = $po == 6'b00111x ||
                     $po == 6'b0110X0 ||
                     $po == 6'b011100 ||
                     $po == 6'b011010 ||
                     $po == 6'b001011;
         $is_ds_instr = ($po == 6'b111x10);
         $is_i_instr  = ($po == 6'b010010);
         $is_x_instr  = ($po == 31) && ($xo != 266 && $xo != 40);
         $is_xo_instr = ($po == 31) && ($xo == 266 || $xo == 40);
         $is_b_instr = ($po == 19);

         // Check whether the given fields are valid
         $rs_rt_valid = !($is_i_instr || $is_b_instr);
         $ra_valid = !($is_i_instr || $is_b_instr);
         $rb_valid = ($is_x_instr || $is_xo_instr);
         $xo_valid = !($is_i_instr || $is_d_instr || $is_b_instr);

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
         $is_ld    = $po == 58 ;
         $is_std   = $po == 62 ;
         $is_b     = $po == 18;
         $is_bc    = $po == 19;
         $is_cmp   = $is_x_instr;
         $is_cmpi  = $po == 11;

         // Determining the correct source and destination regsiters based on the instruction
         $rd[4:0] = ($is_xo_instr || $is_addi || $is_addis || $is_ld) ? $rs_rt :
                  (($is_x_instr && !($is_cmp)) || $is_andi || $is_ori || $is_xori) ? $ra :
                  32;
         $rs1[4:0] = ($is_xo_instr || $is_ds_instr || $is_addi || $is_addis || $is_cmp || $is_cmpi) ? $ra :
                     (($is_x_instr && !($is_cmp)) || $is_andi || $is_ori || $is_xori) ? $rs_rt :
                     0;

      @2 // ALU Execution (EX) Stage
         
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
                        $is_cmp   ? /top>>0$src1_value < /top>>0$src2_value ? {4'b1000, 60'b0} : (/top>>0$src1_value > /top>>0$src2_value? {4'b010, 60'b0} : {4'b0010, 60'b0}) :
                        $is_cmpi  ? /top>>0$src1_value < $si ? {4'b1000, 60'b0} : (/top>>0$src1_value > $si? {4'b0100, 60'b0} : {4'b0010, 60'b0}) :
                        64'b0;

         // Update the CR Resgister
         $cr[63:0] = ($is_cmp || $is_cmpi) ? $result : 64'b0;

         // Determine the branch target address
         $br_tgt[63:0] =  $is_b  ? ($instr[1] ? $li : $li+$pc) :
                          $is_bc ? ($cr[32+$bi] ? ($instr[2] ? $bd : $bd + $pc) : $pc4) :
                          64'b0;


   `BOGUS_USE(|cpu>>1$xo_valid);
   // Assert these to end simulation (before Makerchip cycle limit).
   *failed = 1'b0;
   *passed = *cyc_cnt > 10;

   |cpu // Instantiating the instruction memory in stage 0 (IF Stage)
      m4+imem(@0)

   // Instantiating the register file and data memory (MEM and WB take place in these modules itself)
   m4+rf(32, 64, |cpu>>0$reset, (|cpu>>1$rd < 32) ? |cpu>>1$rs_rt_valid : 1'b0, |cpu>>1$rd, |cpu>>1$is_ld ? /top>>0$ld_data : |cpu>>2$result, |cpu>>1$ra_valid, |cpu>>1$rs1, $src1_value, |cpu>>1$rb_valid, |cpu>>1$rb, $src2_value)
   m4+dmem(32, 64, |cpu>>0$reset, |cpu>>2$result[6:2], |cpu>>1$is_std, $src2_value, |cpu>>1$is_ld, $ld_data)
\SV
   endmodule
