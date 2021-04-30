//-------------------DECLARATIONS-------------------------//

// Note - Adopted from - https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/blob/main/lib/risc-v_shell_lib.tlv#L123-L236
// I have removed the Viz part of this code for simplicity. You can add it back from the above source if you are building up on the RISC-V core itself.

// Instruction memory in |cpu at the given stage.
\TLV imem(@_stage)
   // Instruction Memory containing program defined by m4_asm(...) instantiations.
   @_stage
      \SV_plus
         // The program in an instruction memory.
         parameter N = 2;
         logic [31:0] instrs [0:N-1];
         // RISC-V has an inline assembler which automatically fills this SV array. For POWER, you can do this manually by changing the assignment below. Note that it is not mandatory to split instruction bitfields like the example below (you can write 32'b00000000000100110011 instead of {7'b0000000, 5'd0, 5'd0, 3'b000, 5'd10, 7'b0110011} if you prefer.
         assign instrs = '{
            32'h02006338,32'h02006337
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
