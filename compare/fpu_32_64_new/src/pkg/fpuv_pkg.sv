// Copyright 2019 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Stefan Mach <smach@iis.ee.ethz.ch>
//
// Additional contributions by: Leon Dragic <leon.dragic@fer.hr>
//                              Mate Kovac <mate.kovac@fer.hr>
//
// Change history: 09/03/2020 - Added MASK_WORD parameter.
//                 30/06/2020 - Changed number of operands for all operations groups to 3 to enable forwarding of inactive element select.
//                 24/01/2021 - Added configuration of divsqrt bits per cycle to the fpu_implementation_t structure
//

package fpuv_pkg;

  // -------------------------------------------
  //                  FORMATS
  // -------------------------------------------
  // ---------
  // FP TYPES
  // ---------
  // | Enumerator | Format           | Width  | EXP_BITS | MAN_BITS
  // |:----------:|------------------|-------:|:--------:|:--------:
  // | FP32       | IEEE binary32    | 32 bit | 8        | 23
  // | FP64       | IEEE binary64    | 64 bit | 11       | 52
  // | FP16       | IEEE binary16    | 16 bit | 5        | 10
  // | FP8        | binary8          |  8 bit | 5        | 2
  // | FP16ALT    | binary16alt      | 16 bit | 8        | 7
  // *NOTE:* Add new formats only at the end of the enumeration for backwards compatibilty!

  // Encoding for a format
  typedef struct packed {
    int unsigned exp_bits;
    int unsigned man_bits;
  } fp_encoding_t;

  localparam int unsigned NUM_FP_FORMATS = 5; // change me to add formats
  localparam int unsigned FP_FORMAT_BITS = $clog2(NUM_FP_FORMATS);

  // FP formats
  typedef enum logic [FP_FORMAT_BITS-1:0] {
    FP8     = 'd0,
    FP16    = 'd1,
    FP32    = 'd2,
    FP64    = 'd3,
    FP16ALT = 'd4
    // add new formats here
  } fp_format_e;

  // Encodings for supported FP formats
  localparam fp_encoding_t [0:NUM_FP_FORMATS-1] FP_ENCODINGS  = '{
    '{5,  2},  // custom binary8
    '{5,  10}, // IEEE binary16 (half)
    '{8,  23}, // IEEE binary32 (single)
    '{11, 52}, // IEEE binary64 (double)
    '{8,  7}   // custom binary16alt
    // add new formats here
  };

  typedef logic [0:NUM_FP_FORMATS-1]       fmt_logic_t;    // Logic indexed by FP format (for masks)
  typedef logic [0:NUM_FP_FORMATS-1][31:0] fmt_unsigned_t; // Unsigned indexed by FP format

  localparam fmt_logic_t CPK_FORMATS = 5'b00110; // FP32 and FP64 can provide CPK only

  // ---------
  // INT TYPES
  // ---------
  // | Enumerator | Width  |
  // |:----------:|-------:|
  // | INT8       |  8 bit |
  // | INT16      | 16 bit |
  // | INT32      | 32 bit |
  // | INT64      | 64 bit |
  // *NOTE:* Add new formats only at the end of the enumeration for backwards compatibilty!

  localparam int unsigned NUM_INT_FORMATS = 4; // change me to add formats
  localparam int unsigned INT_FORMAT_BITS = $clog2(NUM_INT_FORMATS);

  // Int formats
  typedef enum logic [INT_FORMAT_BITS-1:0] {
    INT8,
    INT16,
    INT32,
    INT64
    // add new formats here
  } int_format_e;

  // Returns the width of an INT format by index
  function automatic int unsigned int_width(int_format_e ifmt);
    unique case (ifmt)
      INT8:  return 8;
      INT16: return 16;
      INT32: return 32;
      INT64: return 64;
    endcase
  endfunction

  typedef logic [0:NUM_INT_FORMATS-1] ifmt_logic_t; // Logic indexed by INT format (for masks)

// -------------------------------------------
//              FP OPERATIONS
// -------------------------------------------
   localparam int unsigned NUM_OPGROUPS = 4;

   // Each FP operation belongs to an operation group
   typedef enum logic [1:0] {
      ADDMUL, DIVSQRT, NONCOMP, CONV
   } opgroup_e;

   localparam int unsigned OP_BITS = 4;

   typedef enum logic [OP_BITS-1:0] {
      FMADD, FNMSUB, ADD, MUL,     // ADDMUL operation group
      DIV, SQRT,                   // DIVSQRT operation group
      SGNJ, MINMAX, CMP, CLASSIFY, // NONCOMP operation group
      F2F, F2I, I2F, CPKAB, CPKCD  // CONV operation group
   } operation_e;

   typedef enum logic [2:0] { // FOG - Fp Operation Group
      FOG_ADD, FOG_MUL, FOG_FMA,
      FOG_CMP, FOG_SIGNJ,
      FOG_UNARY,
      FOG_DIV_SQRT
      // 111 reserved
   } fp_op_group_e;

   typedef enum logic [2:0] {
      FCMP_EQ  = 3'b000,
      FCMP_LE  = 3'b001,
      // 010 reserved
      FCMP_LT  = 3'b011,
      FCMP_NE  = 3'b100, // also used for MIN
      FCMP_GT  = 3'b101,
      FCMP_MAX = 3'b110,
      FCMP_GE  = 3'b111
   } fp_cmp_e;

   typedef enum logic [2:0] {
      SIGNJ_B, SIGNJ_N, SIGNJ_X // 011 - 111 reserved. _B stands for basic
   } sgnj_e;

   typedef enum logic [2:0] {
      FUNA_CLASSIFY = 3'b000,
      FUNA_F2F      = 3'b001,
      FUNA_I2F      = 3'b010,
      FUNA_F2I      = 3'b011,
      FUNA_U2F      = 3'b100,
      FUNA_F2U      = 3'b101
      // 110 - 111 reserved. U -> Unsigned int
      // TODO: Remap encoding
   } fp_unary_e;

   typedef enum logic [2:0] {
      FDIV_DIV, FDIV_SQRT, FDIV_REC7, FDIV_RSQRT7
      // 100 - 111 reserved
   } fp_div_sqrt_e;

   // All members of packed unions must be of the same size, hence we need padding
   typedef union packed {
      struct packed {
         logic [1:0] padding;
         logic       add_sub;
      } add;
      // nothing needed for MUL
      struct packed {
         logic padding;
         logic negated;
         logic add_sub;
      } fma;
      fp_cmp_e      cmp;
      sgnj_e        sgnj;
      fp_unary_e    unary;
      fp_div_sqrt_e div_sqrt;
   } fp_op_ctrl_t;

// -------------------------------------------
//             RISC-V FP-SPECIFIC
// -------------------------------------------
   // Rounding modes
   typedef enum logic [2:0] {
      FRM_RNE = 3'b000,
      FRM_RTZ = 3'b001,
      FRM_RDN = 3'b010,
      FRM_RUP = 3'b011,
      FRM_RMM = 3'b100,
      FRM_ROD = 3'b101,
      // 110 reserved
      FRM_DYN = 3'b111 // illegal for vector
   } frm_e;

   // Status flags
   typedef struct packed {
      logic nv; // Invalid
      logic dz; // Divide by zero
      logic of; // Overflow
      logic uf; // Underflow
      logic nx; // Inexact
   } fflags_t;

   // Information about a floating point value
   typedef struct packed {
      logic is_normal;     // is the value normal
      logic is_subnormal;  // is the value subnormal
      logic is_zero;       // is the value zero
      logic is_inf;        // is the value infinity
      logic is_nan;        // is the value NaN
      logic is_signalling; // is the value a signalling NaN
      logic is_quiet;      // is the value a quiet NaN
      logic is_boxed;      // is the value properly NaN-boxed (RISC-V specific)
   } fp_info_t;

   // Classification mask
   typedef enum logic [9:0] {
      NEGINF     = 10'b00_0000_0001,
      NEGNORM    = 10'b00_0000_0010,
      NEGSUBNORM = 10'b00_0000_0100,
      NEGZERO    = 10'b00_0000_1000,
      POSZERO    = 10'b00_0001_0000,
      POSSUBNORM = 10'b00_0010_0000,
      POSNORM    = 10'b00_0100_0000,
      POSINF     = 10'b00_1000_0000,
      SNAN       = 10'b01_0000_0000,
      QNAN       = 10'b10_0000_0000
   } classmask_e;

   // --------------------------
   // Vector extension-specific
   // --------------------------
   //

  //localparam MIN_SEW = 8; // Smallest number of bits of a vector element
  //localparam ELEN = 64; // Maximum size in bits of a vector element

  // localparam MAX_ELE_FU       = ELEN/MIN_SEW; //..maximum number of (small) elements per ELEN

   localparam int unsigned MAX_ELE_FU = 8; // maximum number of elements (operands) on input: 64/8


   localparam int unsigned SEW_BITS = 3;

    typedef enum logic [SEW_BITS-1:0] {
    SEW8    = 3'b000,
    SEW16   = 3'b001,
    SEW32   = 3'b010,
    SEW64   = 3'b011,
    SEW128  = 3'b100,
    SEW256  = 3'b101,
    SEW512  = 3'b110,
    SEW1024 = 3'b111
    } vsew_e; // FM: ToDo-> Rename to vsew_e according to coding guidelines for enumeration types (and values should be UpperCamelCase)

/*   localparam int unsigned SEW_BITS = 3;
   typedef enum logic [SEW_BITS-1:0] {
      SEW8  = 'b000,
      SEW16 = 'b001,
      SEW32 = 'b010,
      SEW64 = 'b011
   } vsew_e;
*/
   typedef enum logic [1:0] {
      SRC1, SRC2, SRC3
   } src_id_e;

   typedef struct packed {
      logic widen; // Widen this source operand. Used for mixed-width operations. Only used for certain operations (see RVV)
   } fp_src_ctrl_t;

   typedef enum logic [1:0] {
      DST_BASE, DST_WIDEN, DST_NARROW, DST_MASK // FDST_BASE: baseline behaviour. FDST_MASK: Output is mask, used to distinguish comparision (generates mask) and max/min
   } dst_ctrl_e;

   typedef struct packed {
      logic    masked;
      src_id_e old_dst; // which source in op_src_i[] contains the old_dst (used when operation is masked out)
   } msk_ctrl_t;

   typedef logic [6:0] lut_elem_t;

// -------------------------------------------
//             FPU CONFIGURATION
// -------------------------------------------
  // Pipelining registers can be inserted (at elaboration time) into operational units
  typedef enum logic [1:0] {
    BEFORE,     // registers are inserted at the inputs of the unit
    AFTER,      // registers are inserted at the outputs of the unit
    INSIDE,     // registers are inserted at predetermined (suboptimal) locations in the unit
    DISTRIBUTED // registers are evenly distributed, INSIDE >= AFTER >= BEFORE
  } pipe_config_t;

   localparam int unsigned PIPE_SKID_GEN = 0; // When enabled, a skid buffer is generated inside pipeline stages (for registered ready signal, otherwise it is combinatorial)

  // Arithmetic units can be arranged in parallel (per format), merged (multi-format) or not at all.
  typedef enum logic [1:0] {
    DISABLED, // arithmetic units are not generated
    PARALLEL, // arithmetic units are generated in prallel slices, one for each format
    MERGED    // arithmetic units are contained within a merged unit holding multiple formats
  } unit_type_t;

  // Array of unit types indexed by format
  typedef unit_type_t [0:NUM_FP_FORMATS-1] fmt_unit_types_t;

  // Array of format-specific unit types by opgroup
  typedef fmt_unit_types_t [0:NUM_OPGROUPS-1] opgrp_fmt_unit_types_t;
  // same with unsigned
  typedef fmt_unsigned_t [0:NUM_OPGROUPS-1] opgrp_fmt_unsigned_t;

  // FPU configuration: features
  typedef struct packed {
    int unsigned Width;
    logic        EnableVectors;
    logic        EnableNanBox;
    logic        EnableOutOfOrder;
    fmt_logic_t  FpFmtMask;
    ifmt_logic_t IntFmtMask;
  } fpu_features_t;

  localparam fpu_features_t RV64D = '{
    Width:            64,
    EnableVectors:    1'b0,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b11000,
    IntFmtMask:       4'b0011
  };

  localparam fpu_features_t RV32D = '{
    Width:            64,
    EnableVectors:    1'b1,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b11000,
    IntFmtMask:       4'b0010
  };

  localparam fpu_features_t RV32F = '{
    Width:            32,
    EnableVectors:    1'b0,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b10000,
    IntFmtMask:       4'b0010
  };

  localparam fpu_features_t RV64D_Xsflt = '{
    Width:            64,
    EnableVectors:    1'b1,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b11111,
    IntFmtMask:       4'b1111
  };

  localparam fpu_features_t RV32F_Xsflt = '{
    Width:            32,
    EnableVectors:    1'b1,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b10111,
    IntFmtMask:       4'b1110
  };

  localparam fpu_features_t RV32F_Xf16alt_Xfvec = '{
    Width:            32,
    EnableVectors:    1'b1,
    EnableNanBox:     1'b1,
    EnableOutOfOrder: 1'b1,
    FpFmtMask:        5'b10001,
    IntFmtMask:       4'b0110
  };

   localparam fpuv_pkg::fpu_features_t EPI_RV64D = '{
      Width:             64,
      EnableVectors:     1'b1,
      EnableNanBox:      1'b1,
      EnableOutOfOrder:  1'b0,
      FpFmtMask:         5'b00110,
      IntFmtMask:        4'b0011
   };

  // FPU configuraion: implementation
  typedef struct packed {
    opgrp_fmt_unsigned_t   PipeRegs;
    opgrp_fmt_unit_types_t UnitTypes;
    int unsigned           DivBitsPerCycle;
    pipe_config_t          PipeConfig;
  } fpu_implementation_t;

  localparam fpu_implementation_t DEFAULT_NOREGS = '{
    PipeRegs:   '{default: 0},
    UnitTypes:  '{'{default: PARALLEL}, // ADDMUL
                  '{default: MERGED},   // DIVSQRT
                  '{default: PARALLEL}, // NONCOMP
                  '{default: MERGED}},  // CONV
    DivBitsPerCycle : 1,
    PipeConfig: BEFORE
  };

  localparam fpu_implementation_t DEFAULT_SNITCH = '{
    PipeRegs:   '{default: 1},
    UnitTypes:  '{'{default: PARALLEL}, // ADDMUL
                  '{default: DISABLED}, // DIVSQRT
                  '{default: PARALLEL}, // NONCOMP
                  '{default: MERGED}},  // CONV
    DivBitsPerCycle : 1,
    PipeConfig: BEFORE
  };

   localparam fpuv_pkg::fpu_implementation_t EPI_INIT = '{
      PipeRegs:   '{'{default: 5}, // ADDMUL
                  '{default: 5},   // DIVSQRT
                  '{default: 5},   // NONCOMP
                  '{default: 5}},  // CONV
      UnitTypes:  '{'{default: fpuv_pkg::MERGED}, // ADDMUL
                  '{default: fpuv_pkg::MERGED},   // DIVSQRT
                  '{default: fpuv_pkg::PARALLEL}, // NONCOMP
                  '{default: fpuv_pkg::MERGED}},  // CONV
      DivBitsPerCycle: 1,
      PipeConfig: fpuv_pkg::DISTRIBUTED
   };

  // -----------------------
  // Synthesis optimization
  // -----------------------
  localparam logic DONT_CARE = 1'b1; // the value to assign as don't care

// -------------------------------------------
//                FUNCTIONS
// -------------------------------------------

  // -------------------------
  // General helper functions
  // -------------------------
  function automatic int minimum(int a, int b);
    return (a < b) ? a : b;
  endfunction

  function automatic int maximum(int a, int b);
    return (a > b) ? a : b;
  endfunction

  // -------------------------------------------
  // Helper functions for FP formats and values
  // -------------------------------------------
  // Returns the width of a FP format
  function automatic int unsigned fp_width(fp_format_e fmt);
    return FP_ENCODINGS[fmt].exp_bits + FP_ENCODINGS[fmt].man_bits + 1;
  endfunction

  // Returns the widest FP format present
  function automatic int unsigned max_fp_width(fmt_logic_t cfg);
    automatic int unsigned res = 0;
    for (int unsigned i = 0; i < NUM_FP_FORMATS; i++)
      if (cfg[i])
        res = unsigned'(maximum(res, fp_width(fp_format_e'(i))));
    return res;
  endfunction

  // Returns the narrowest FP format present
  function automatic int unsigned min_fp_width(fmt_logic_t cfg);
    automatic int unsigned res = max_fp_width(cfg);
    for (int unsigned i = 0; i < NUM_FP_FORMATS; i++)
      if (cfg[i])
        res = unsigned'(minimum(res, fp_width(fp_format_e'(i))));
    return res;
  endfunction

  // Returns the number of expoent bits for a format
  function automatic int unsigned exp_bits(fp_format_e fmt);
    return FP_ENCODINGS[fmt].exp_bits;
  endfunction

  // Returns the number of mantissa bits for a format
  function automatic int unsigned man_bits(fp_format_e fmt);
    return FP_ENCODINGS[fmt].man_bits;
  endfunction

  // Returns the bias value for a given format (as per IEEE 754-2008)
  function automatic int unsigned bias(fp_format_e fmt);
    return unsigned'(2**(FP_ENCODINGS[fmt].exp_bits-1)-1); // symmetrical bias
  endfunction

  function automatic fp_encoding_t super_format(fmt_logic_t cfg);
    automatic fp_encoding_t res;
    res = '0;
    for (int unsigned fmt = 0; fmt < NUM_FP_FORMATS; fmt++)
      if (cfg[fmt]) begin // only active format
        res.exp_bits = unsigned'(maximum(res.exp_bits, exp_bits(fp_format_e'(fmt))));
        res.man_bits = unsigned'(maximum(res.man_bits, man_bits(fp_format_e'(fmt))));
      end
    return res;
  endfunction

  // -------------------------------------------
  // Helper functions for INT formats and values
  // -------------------------------------------
  // Returns the widest INT format present
  function automatic int unsigned max_int_width(ifmt_logic_t cfg);
    automatic int unsigned res = 0;
    for (int ifmt = 0; ifmt < NUM_INT_FORMATS; ifmt++) begin
      if (cfg[ifmt]) res = unsigned'(maximum(res, int_width(int_format_e'(ifmt))));
    end
    return res;
  endfunction

  // --------------------------------------------------
  // Helper functions for operations and FPU structure
  // --------------------------------------------------
  // Returns the operation group of the given operation
  function automatic opgroup_e get_opgroup(operation_e op);
    unique case (op)
      FMADD, FNMSUB, ADD, MUL:     return ADDMUL;
      DIV, SQRT:                   return DIVSQRT;
      SGNJ, MINMAX, CMP, CLASSIFY: return NONCOMP;
      F2F, F2I, I2F, CPKAB, CPKCD: return CONV;
      default:                     return NONCOMP;
    endcase
  endfunction

  // Returns the number of operands by operation group
  function automatic int unsigned num_operands(opgroup_e grp);
    unique case (grp)
      ADDMUL:  return 3;
      DIVSQRT: return 3;
      NONCOMP: return 3;
      CONV:    return 3; // vectorial casts use 3 operands
      default: return 0;
    endcase
  endfunction

  // Returns the number of lanes according to width, format and vectors
  function automatic int unsigned num_lanes(int unsigned width, fp_format_e fmt, logic vec);
    return vec ? width / fp_width(fmt) : 1; // if no vectors, only one lane
  endfunction

  // Returns the maximum number of lanes in the FPU according to width, format config and vectors
  function automatic int unsigned max_num_lanes(int unsigned width, fmt_logic_t cfg, logic vec);
    return vec ? width / min_fp_width(cfg) : 1; // if no vectors, only one lane
  endfunction

  // Returns a mask of active FP formats that are present in lane lane_no of a multiformat slice
  function automatic fmt_logic_t get_lane_formats(int unsigned width,
                                                  fmt_logic_t cfg,
                                                  int unsigned lane_no);
    automatic fmt_logic_t res;
    for (int unsigned fmt = 0; fmt < NUM_FP_FORMATS; fmt++)
      // Mask active formats with the number of lanes for that format
      res[fmt] = cfg[fmt] & (width / fp_width(fp_format_e'(fmt)) > lane_no);
    return res;
  endfunction

  // Returns a mask of active INT formats that are present in lane lane_no of a multiformat slice
  function automatic ifmt_logic_t get_lane_int_formats(int unsigned width,
                                                       fmt_logic_t cfg,
                                                       ifmt_logic_t icfg,
                                                       int unsigned lane_no);
    automatic ifmt_logic_t res;
    automatic fmt_logic_t lanefmts;
    res = '0;
    lanefmts = get_lane_formats(width, cfg, lane_no);

    for (int unsigned ifmt = 0; ifmt < NUM_INT_FORMATS; ifmt++)
      for (int unsigned fmt = 0; fmt < NUM_FP_FORMATS; fmt++)
        // Mask active int formats with the width of the float formats
        if ((fp_width(fp_format_e'(fmt)) == int_width(int_format_e'(ifmt))))
          res[ifmt] |= icfg[ifmt] && lanefmts[fmt];
    return res;
  endfunction

  // Returns a mask of active FP formats that are present in lane lane_no of a CONV slice
  function automatic fmt_logic_t get_conv_lane_formats(int unsigned width,
                                                       fmt_logic_t cfg,
                                                       int unsigned lane_no);
    automatic fmt_logic_t res;
    for (int unsigned fmt = 0; fmt < NUM_FP_FORMATS; fmt++)
      // Mask active formats with the number of lanes for that format, CPK at least twice
      res[fmt] = cfg[fmt] && ((width / fp_width(fp_format_e'(fmt)) > lane_no) ||
                             (CPK_FORMATS[fmt] && (lane_no < 2)));
    return res;
  endfunction

  // Returns a mask of active INT formats that are present in lane lane_no of a CONV slice
  function automatic ifmt_logic_t get_conv_lane_int_formats(int unsigned width,
                                                            fmt_logic_t cfg,
                                                            ifmt_logic_t icfg,
                                                            int unsigned lane_no);
    automatic ifmt_logic_t res;
    automatic fmt_logic_t lanefmts;
    res = '0;
    lanefmts = get_conv_lane_formats(width, cfg, lane_no);

    for (int unsigned ifmt = 0; ifmt < NUM_INT_FORMATS; ifmt++)
      for (int unsigned fmt = 0; fmt < NUM_FP_FORMATS; fmt++)
        // Mask active int formats with the width of the float formats
        res[ifmt] |= icfg[ifmt] && lanefmts[fmt] &&
                     (fp_width(fp_format_e'(fmt)) == int_width(int_format_e'(ifmt)));
    return res;
  endfunction

  // Return whether any active format is set as MERGED
  function automatic logic any_enabled_multi(fmt_unit_types_t types, fmt_logic_t cfg);
    for (int unsigned i = 0; i < NUM_FP_FORMATS; i++)
      if (cfg[i] && types[i] == MERGED)
        return 1'b1;
      return 1'b0;
  endfunction

  // Return whether the given format is the first active one set as MERGED
  function automatic logic is_first_enabled_multi(fp_format_e fmt,
                                                  fmt_unit_types_t types,
                                                  fmt_logic_t cfg);
    for (int unsigned i = 0; i < NUM_FP_FORMATS; i++) begin
      if (cfg[i] && types[i] == MERGED) return (fp_format_e'(i) == fmt);
    end
    return 1'b0;
  endfunction

  // Returns the first format that is active and is set as MERGED
  function automatic fp_format_e get_first_enabled_multi(fmt_unit_types_t types, fmt_logic_t cfg);
    for (int unsigned i = 0; i < NUM_FP_FORMATS; i++)
      if (cfg[i] && types[i] == MERGED)
        return fp_format_e'(i);
      return fp_format_e'(0);
  endfunction

   // Returns the operation group of the given operation
   function automatic opgroup_e fog_get_opgroup(fp_op_group_e opgroup, fp_unary_e opunary);
      case (opgroup)
         FOG_ADD, FOG_MUL, FOG_FMA: return ADDMUL;
         FOG_DIV_SQRT:              return DIVSQRT;
         FOG_SIGNJ, FOG_CMP:        return NONCOMP;
         FOG_UNARY : begin
            case (opunary)
               FUNA_CLASSIFY:       return NONCOMP;
               FUNA_F2F, FUNA_I2F, FUNA_F2I, FUNA_U2F, FUNA_F2U: return CONV;
               default:             return NONCOMP;
            endcase
         end
         default:                   return NONCOMP;
      endcase
   endfunction

   // Returns the wider format for the given SEW
   function automatic fp_format_e get_wider_sew (vsew_e sew);
      case (sew)
         SEW8, SEW16, SEW32: return fp_format_e'(sew + 1'b1);
         default:            return FP64;
      endcase
   endfunction

   // Returns the narrower format for the given SEW
   function automatic fp_format_e get_narrower_sew (vsew_e sew);
      case (sew)
         SEW16, SEW32, SEW64: return fp_format_e'(sew - 1'b1);
         default:             return FP8;
      endcase
   endfunction

   // Returns the required depth of the FIFO arbiter inside operation group blocks
   function automatic int unsigned get_opgrp_arb_buffer_depth(fmt_logic_t FpFmtMask, fmt_unit_types_t FmtUnitTypes, fmt_unsigned_t FmtPipeRegs);
      int unsigned depth;
      depth = 0;
      for (int unsigned fmt = 0; fmt < int'(NUM_FP_FORMATS); fmt++) begin
         logic IS_FIRST_MERGED = is_first_enabled_multi(fp_format_e'(fmt), FmtUnitTypes, FpFmtMask);
         // Increase depth for every enabled PARALLEL format or once for all MERGED formats
         if (FpFmtMask[fmt] && (FmtUnitTypes[fmt] == PARALLEL || IS_FIRST_MERGED))
            depth += FmtPipeRegs[fmt];
      end
      return depth;
   endfunction

   // Returns the required depth of the top-level FIFO arbiter.
   function automatic int unsigned get_top_arb_buffer_depth(fmt_logic_t FpFmtMask, opgrp_fmt_unit_types_t UnitTypes, opgrp_fmt_unsigned_t PipeRegs);
      int unsigned depth;
      depth = 0;
      for (int unsigned opgrp = 0; opgrp < int'(NUM_OPGROUPS); opgrp++) begin
         depth += get_opgrp_arb_buffer_depth(FpFmtMask, UnitTypes[opgrp], PipeRegs[opgrp]);
      end
      return depth;
   endfunction

   function automatic logic get_rnd_direction(frm_e rnd_mode, logic [1:0] round_sticky, logic sign, logic abs_lsb);
      logic round_up;
      unique case (rnd_mode)
         FRM_RNE: // Decide accoring to round/sticky bits
         unique case (round_sticky)
            2'b00,
            2'b01: round_up = 1'b0;           // < ulp/2 away, round down
            2'b10: round_up = abs_lsb;        // = ulp/2 away, round towards even result
            2'b11: round_up = 1'b1;           // > ulp/2 away, round up
            default: round_up = DONT_CARE;
         endcase
         FRM_RTZ: round_up = 1'b0; // always round down
         FRM_RDN: round_up = (| round_sticky) ? sign  : 1'b0; // to 0 if +, away if -
         FRM_RUP: round_up = (| round_sticky) ? ~sign : 1'b0; // to 0 if -, away if +
         FRM_RMM: round_up = round_sticky[1]; // round down if < ulp/2 away, else up
         FRM_ROD: round_up = (| round_sticky) & ~abs_lsb; // round towards odd: only round up if the result is even and inexact
         default: round_up = DONT_CARE; // propagate x
      endcase
      return round_up;
   endfunction

   function automatic lut_elem_t rsqrt7_lut (lut_elem_t operand);
   case (operand)
      lut_elem_t'( 0  ) : return lut_elem_t'(52);
      lut_elem_t'( 1  ) : return lut_elem_t'(51);
      lut_elem_t'( 2  ) : return lut_elem_t'(50);
      lut_elem_t'( 3  ) : return lut_elem_t'(48);
      lut_elem_t'( 4  ) : return lut_elem_t'(47);
      lut_elem_t'( 5  ) : return lut_elem_t'(46);
      lut_elem_t'( 6  ) : return lut_elem_t'(44);
      lut_elem_t'( 7  ) : return lut_elem_t'(43);
      lut_elem_t'( 8  ) : return lut_elem_t'(42);
      lut_elem_t'( 9  ) : return lut_elem_t'(41);
      lut_elem_t'( 10 ) : return lut_elem_t'(40);
      lut_elem_t'( 11 ) : return lut_elem_t'(39);
      lut_elem_t'( 12 ) : return lut_elem_t'(38);
      lut_elem_t'( 13 ) : return lut_elem_t'(36);
      lut_elem_t'( 14 ) : return lut_elem_t'(35);
      lut_elem_t'( 15 ) : return lut_elem_t'(34);
      lut_elem_t'( 16 ) : return lut_elem_t'(33);
      lut_elem_t'( 17 ) : return lut_elem_t'(32);
      lut_elem_t'( 18 ) : return lut_elem_t'(31);
      lut_elem_t'( 19 ) : return lut_elem_t'(30);
      lut_elem_t'( 20 ) : return lut_elem_t'(30);
      lut_elem_t'( 21 ) : return lut_elem_t'(29);
      lut_elem_t'( 22 ) : return lut_elem_t'(28);
      lut_elem_t'( 23 ) : return lut_elem_t'(27);
      lut_elem_t'( 24 ) : return lut_elem_t'(26);
      lut_elem_t'( 25 ) : return lut_elem_t'(25);
      lut_elem_t'( 26 ) : return lut_elem_t'(24);
      lut_elem_t'( 27 ) : return lut_elem_t'(23);
      lut_elem_t'( 28 ) : return lut_elem_t'(23);
      lut_elem_t'( 29 ) : return lut_elem_t'(22);
      lut_elem_t'( 30 ) : return lut_elem_t'(21);
      lut_elem_t'( 31 ) : return lut_elem_t'(20);
      lut_elem_t'( 32 ) : return lut_elem_t'(19);
      lut_elem_t'( 33 ) : return lut_elem_t'(19);
      lut_elem_t'( 34 ) : return lut_elem_t'(18);
      lut_elem_t'( 35 ) : return lut_elem_t'(17);
      lut_elem_t'( 36 ) : return lut_elem_t'(16);
      lut_elem_t'( 37 ) : return lut_elem_t'(16);
      lut_elem_t'( 38 ) : return lut_elem_t'(15);
      lut_elem_t'( 39 ) : return lut_elem_t'(14);
      lut_elem_t'( 40 ) : return lut_elem_t'(14);
      lut_elem_t'( 41 ) : return lut_elem_t'(13);
      lut_elem_t'( 42 ) : return lut_elem_t'(12);
      lut_elem_t'( 43 ) : return lut_elem_t'(12);
      lut_elem_t'( 44 ) : return lut_elem_t'(11);
      lut_elem_t'( 45 ) : return lut_elem_t'(10);
      lut_elem_t'( 46 ) : return lut_elem_t'(10);
      lut_elem_t'( 47 ) : return lut_elem_t'(9);
      lut_elem_t'( 48 ) : return lut_elem_t'(9);
      lut_elem_t'( 49 ) : return lut_elem_t'(8);
      lut_elem_t'( 50 ) : return lut_elem_t'(7);
      lut_elem_t'( 51 ) : return lut_elem_t'(7);
      lut_elem_t'( 52 ) : return lut_elem_t'(6);
      lut_elem_t'( 53 ) : return lut_elem_t'(6);
      lut_elem_t'( 54 ) : return lut_elem_t'(5);
      lut_elem_t'( 55 ) : return lut_elem_t'(4);
      lut_elem_t'( 56 ) : return lut_elem_t'(4);
      lut_elem_t'( 57 ) : return lut_elem_t'(3);
      lut_elem_t'( 58 ) : return lut_elem_t'(3);
      lut_elem_t'( 59 ) : return lut_elem_t'(2);
      lut_elem_t'( 60 ) : return lut_elem_t'(2);
      lut_elem_t'( 61 ) : return lut_elem_t'(1);
      lut_elem_t'( 62 ) : return lut_elem_t'(1);
      lut_elem_t'( 63 ) : return lut_elem_t'(0);
      lut_elem_t'( 64 ) : return lut_elem_t'(127);
      lut_elem_t'( 65 ) : return lut_elem_t'(125);
      lut_elem_t'( 66 ) : return lut_elem_t'(123);
      lut_elem_t'( 67 ) : return lut_elem_t'(121);
      lut_elem_t'( 68 ) : return lut_elem_t'(119);
      lut_elem_t'( 69 ) : return lut_elem_t'(118);
      lut_elem_t'( 70 ) : return lut_elem_t'(116);
      lut_elem_t'( 71 ) : return lut_elem_t'(114);
      lut_elem_t'( 72 ) : return lut_elem_t'(113);
      lut_elem_t'( 73 ) : return lut_elem_t'(111);
      lut_elem_t'( 74 ) : return lut_elem_t'(109);
      lut_elem_t'( 75 ) : return lut_elem_t'(108);
      lut_elem_t'( 76 ) : return lut_elem_t'(106);
      lut_elem_t'( 77 ) : return lut_elem_t'(105);
      lut_elem_t'( 78 ) : return lut_elem_t'(103);
      lut_elem_t'( 79 ) : return lut_elem_t'(102);
      lut_elem_t'( 80 ) : return lut_elem_t'(100);
      lut_elem_t'( 81 ) : return lut_elem_t'(99);
      lut_elem_t'( 82 ) : return lut_elem_t'(97);
      lut_elem_t'( 83 ) : return lut_elem_t'(96);
      lut_elem_t'( 84 ) : return lut_elem_t'(95);
      lut_elem_t'( 85 ) : return lut_elem_t'(93);
      lut_elem_t'( 86 ) : return lut_elem_t'(92);
      lut_elem_t'( 87 ) : return lut_elem_t'(91);
      lut_elem_t'( 88 ) : return lut_elem_t'(90);
      lut_elem_t'( 89 ) : return lut_elem_t'(88);
      lut_elem_t'( 90 ) : return lut_elem_t'(87);
      lut_elem_t'( 91 ) : return lut_elem_t'(86);
      lut_elem_t'( 92 ) : return lut_elem_t'(85);
      lut_elem_t'( 93 ) : return lut_elem_t'(84);
      lut_elem_t'( 94 ) : return lut_elem_t'(83);
      lut_elem_t'( 95 ) : return lut_elem_t'(82);
      lut_elem_t'( 96 ) : return lut_elem_t'(80);
      lut_elem_t'( 97 ) : return lut_elem_t'(79);
      lut_elem_t'( 98 ) : return lut_elem_t'(78);
      lut_elem_t'( 99 ) : return lut_elem_t'(77);
      lut_elem_t'( 100) : return lut_elem_t'(76);
      lut_elem_t'( 101) : return lut_elem_t'(75);
      lut_elem_t'( 102) : return lut_elem_t'(74);
      lut_elem_t'( 103) : return lut_elem_t'(73);
      lut_elem_t'( 104) : return lut_elem_t'(72);
      lut_elem_t'( 105) : return lut_elem_t'(71);
      lut_elem_t'( 106) : return lut_elem_t'(70);
      lut_elem_t'( 107) : return lut_elem_t'(70);
      lut_elem_t'( 108) : return lut_elem_t'(69);
      lut_elem_t'( 109) : return lut_elem_t'(68);
      lut_elem_t'( 110) : return lut_elem_t'(67);
      lut_elem_t'( 111) : return lut_elem_t'(66);
      lut_elem_t'( 112) : return lut_elem_t'(65);
      lut_elem_t'( 113) : return lut_elem_t'(64);
      lut_elem_t'( 114) : return lut_elem_t'(63);
      lut_elem_t'( 115) : return lut_elem_t'(63);
      lut_elem_t'( 116) : return lut_elem_t'(62);
      lut_elem_t'( 117) : return lut_elem_t'(61);
      lut_elem_t'( 118) : return lut_elem_t'(60);
      lut_elem_t'( 119) : return lut_elem_t'(59);
      lut_elem_t'( 120) : return lut_elem_t'(59);
      lut_elem_t'( 121) : return lut_elem_t'(58);
      lut_elem_t'( 122) : return lut_elem_t'(57);
      lut_elem_t'( 123) : return lut_elem_t'(56);
      lut_elem_t'( 124) : return lut_elem_t'(56);
      lut_elem_t'( 125) : return lut_elem_t'(55);
      lut_elem_t'( 126) : return lut_elem_t'(54);
      lut_elem_t'( 127) : return lut_elem_t'(53);
      default           : return lut_elem_t'(0);
   endcase
endfunction

function automatic lut_elem_t rec7_lut (lut_elem_t operand);
   case (operand)
      lut_elem_t'(  0) : return  lut_elem_t'(127);
      lut_elem_t'(  1) : return  lut_elem_t'(125);
      lut_elem_t'(  2) : return  lut_elem_t'(123);
      lut_elem_t'(  3) : return  lut_elem_t'(121);
      lut_elem_t'(  4) : return  lut_elem_t'(119);
      lut_elem_t'(  5) : return  lut_elem_t'(117);
      lut_elem_t'(  6) : return  lut_elem_t'(116);
      lut_elem_t'(  7) : return  lut_elem_t'(114);
      lut_elem_t'(  8) : return  lut_elem_t'(112);
      lut_elem_t'(  9) : return  lut_elem_t'(110);
      lut_elem_t'( 10) : return  lut_elem_t'(109);
      lut_elem_t'( 11) : return  lut_elem_t'(107);
      lut_elem_t'( 12) : return  lut_elem_t'(105);
      lut_elem_t'( 13) : return  lut_elem_t'(104);
      lut_elem_t'( 14) : return  lut_elem_t'(102);
      lut_elem_t'( 15) : return  lut_elem_t'(100);
      lut_elem_t'( 16) : return  lut_elem_t'( 99);
      lut_elem_t'( 17) : return  lut_elem_t'( 97);
      lut_elem_t'( 18) : return  lut_elem_t'( 96);
      lut_elem_t'( 19) : return  lut_elem_t'( 94);
      lut_elem_t'( 20) : return  lut_elem_t'( 93);
      lut_elem_t'( 21) : return  lut_elem_t'( 91);
      lut_elem_t'( 22) : return  lut_elem_t'( 90);
      lut_elem_t'( 23) : return  lut_elem_t'( 88);
      lut_elem_t'( 24) : return  lut_elem_t'( 87);
      lut_elem_t'( 25) : return  lut_elem_t'( 85);
      lut_elem_t'( 26) : return  lut_elem_t'( 84);
      lut_elem_t'( 27) : return  lut_elem_t'( 83);
      lut_elem_t'( 28) : return  lut_elem_t'( 81);
      lut_elem_t'( 29) : return  lut_elem_t'( 80);
      lut_elem_t'( 30) : return  lut_elem_t'( 79);
      lut_elem_t'( 31) : return  lut_elem_t'( 77);
      lut_elem_t'( 32) : return  lut_elem_t'( 76);
      lut_elem_t'( 33) : return  lut_elem_t'( 75);
      lut_elem_t'( 34) : return  lut_elem_t'( 74);
      lut_elem_t'( 35) : return  lut_elem_t'( 72);
      lut_elem_t'( 36) : return  lut_elem_t'( 71);
      lut_elem_t'( 37) : return  lut_elem_t'( 70);
      lut_elem_t'( 38) : return  lut_elem_t'( 69);
      lut_elem_t'( 39) : return  lut_elem_t'( 68);
      lut_elem_t'( 40) : return  lut_elem_t'( 66);
      lut_elem_t'( 41) : return  lut_elem_t'( 65);
      lut_elem_t'( 42) : return  lut_elem_t'( 64);
      lut_elem_t'( 43) : return  lut_elem_t'( 63);
      lut_elem_t'( 44) : return  lut_elem_t'( 62);
      lut_elem_t'( 45) : return  lut_elem_t'( 61);
      lut_elem_t'( 46) : return  lut_elem_t'( 60);
      lut_elem_t'( 47) : return  lut_elem_t'( 59);
      lut_elem_t'( 48) : return  lut_elem_t'( 58);
      lut_elem_t'( 49) : return  lut_elem_t'( 57);
      lut_elem_t'( 50) : return  lut_elem_t'( 56);
      lut_elem_t'( 51) : return  lut_elem_t'( 55);
      lut_elem_t'( 52) : return  lut_elem_t'( 54);
      lut_elem_t'( 53) : return  lut_elem_t'( 53);
      lut_elem_t'( 54) : return  lut_elem_t'( 52);
      lut_elem_t'( 55) : return  lut_elem_t'( 51);
      lut_elem_t'( 56) : return  lut_elem_t'( 50);
      lut_elem_t'( 57) : return  lut_elem_t'( 49);
      lut_elem_t'( 58) : return  lut_elem_t'( 48);
      lut_elem_t'( 59) : return  lut_elem_t'( 47);
      lut_elem_t'( 60) : return  lut_elem_t'( 46);
      lut_elem_t'( 61) : return  lut_elem_t'( 45);
      lut_elem_t'( 62) : return  lut_elem_t'( 44);
      lut_elem_t'( 63) : return  lut_elem_t'( 43);
      lut_elem_t'( 64) : return  lut_elem_t'( 42);
      lut_elem_t'( 65) : return  lut_elem_t'( 41);
      lut_elem_t'( 66) : return  lut_elem_t'( 40);
      lut_elem_t'( 67) : return  lut_elem_t'( 40);
      lut_elem_t'( 68) : return  lut_elem_t'( 39);
      lut_elem_t'( 69) : return  lut_elem_t'( 38);
      lut_elem_t'( 70) : return  lut_elem_t'( 37);
      lut_elem_t'( 71) : return  lut_elem_t'( 36);
      lut_elem_t'( 72) : return  lut_elem_t'( 35);
      lut_elem_t'( 73) : return  lut_elem_t'( 35);
      lut_elem_t'( 74) : return  lut_elem_t'( 34);
      lut_elem_t'( 75) : return  lut_elem_t'( 33);
      lut_elem_t'( 76) : return  lut_elem_t'( 32);
      lut_elem_t'( 77) : return  lut_elem_t'( 31);
      lut_elem_t'( 78) : return  lut_elem_t'( 31);
      lut_elem_t'( 79) : return  lut_elem_t'( 30);
      lut_elem_t'( 80) : return  lut_elem_t'( 29);
      lut_elem_t'( 81) : return  lut_elem_t'( 28);
      lut_elem_t'( 82) : return  lut_elem_t'( 28);
      lut_elem_t'( 83) : return  lut_elem_t'( 27);
      lut_elem_t'( 84) : return  lut_elem_t'( 26);
      lut_elem_t'( 85) : return  lut_elem_t'( 25);
      lut_elem_t'( 86) : return  lut_elem_t'( 25);
      lut_elem_t'( 87) : return  lut_elem_t'( 24);
      lut_elem_t'( 88) : return  lut_elem_t'( 23);
      lut_elem_t'( 89) : return  lut_elem_t'( 23);
      lut_elem_t'( 90) : return  lut_elem_t'( 22);
      lut_elem_t'( 91) : return  lut_elem_t'( 21);
      lut_elem_t'( 92) : return  lut_elem_t'( 21);
      lut_elem_t'( 93) : return  lut_elem_t'( 20);
      lut_elem_t'( 94) : return  lut_elem_t'( 19);
      lut_elem_t'( 95) : return  lut_elem_t'( 19);
      lut_elem_t'( 96) : return  lut_elem_t'( 18);
      lut_elem_t'( 97) : return  lut_elem_t'( 17);
      lut_elem_t'( 98) : return  lut_elem_t'( 17);
      lut_elem_t'( 99) : return  lut_elem_t'( 16);
      lut_elem_t'(100) : return  lut_elem_t'( 15);
      lut_elem_t'(101) : return  lut_elem_t'( 15);
      lut_elem_t'(102) : return  lut_elem_t'( 14);
      lut_elem_t'(103) : return  lut_elem_t'( 14);
      lut_elem_t'(104) : return  lut_elem_t'( 13);
      lut_elem_t'(105) : return  lut_elem_t'( 12);
      lut_elem_t'(106) : return  lut_elem_t'( 12);
      lut_elem_t'(107) : return  lut_elem_t'( 11);
      lut_elem_t'(108) : return  lut_elem_t'( 11);
      lut_elem_t'(109) : return  lut_elem_t'( 10);
      lut_elem_t'(110) : return  lut_elem_t'(  9);
      lut_elem_t'(111) : return  lut_elem_t'(  9);
      lut_elem_t'(112) : return  lut_elem_t'(  8);
      lut_elem_t'(113) : return  lut_elem_t'(  8);
      lut_elem_t'(114) : return  lut_elem_t'(  7);
      lut_elem_t'(115) : return  lut_elem_t'(  7);
      lut_elem_t'(116) : return  lut_elem_t'(  6);
      lut_elem_t'(117) : return  lut_elem_t'(  5);
      lut_elem_t'(118) : return  lut_elem_t'(  5);
      lut_elem_t'(119) : return  lut_elem_t'(  4);
      lut_elem_t'(120) : return  lut_elem_t'(  4);
      lut_elem_t'(121) : return  lut_elem_t'(  3);
      lut_elem_t'(122) : return  lut_elem_t'(  3);
      lut_elem_t'(123) : return  lut_elem_t'(  2);
      lut_elem_t'(124) : return  lut_elem_t'(  2);
      lut_elem_t'(125) : return  lut_elem_t'(  1);
      lut_elem_t'(126) : return  lut_elem_t'(  1);
      lut_elem_t'(127) : return  lut_elem_t'(  0);
      default          : return  lut_elem_t'(  0);
   endcase
endfunction

endpackage
