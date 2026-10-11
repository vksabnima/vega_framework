// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_008
// DESCRIPTION: Stimulus for address_range_translation. Drives three single-word
//              AHB writes at the low, mid (MSB-set) and high 32-bit address
//              boundaries and checks (via scoreboard) that each HADDR reaches the
//              APB side as PADDR bit-for-bit, with PWDATA==HWDATA and a 1:1 write
//              mapping:
//                T1 : HADDR=0x0000_0000 HWDATA=0x1111_1111 (lowest address)
//                T2 : HADDR=0x8000_0000 HWDATA=0x2222_2222 (mid / MSB set)
//                T3 : HADDR=0xFFFF_FFFC HWDATA=0x3333_3333 (highest aligned word)
//              Each transfer is HSEL=1, HTRANS=NONSEQ, HWRITE=1, SINGLE, word.
//              The bridge must translate each source-side address 1:1 onto the
//              target side (PADDR=HADDR with no truncation or bit drop) and
//              complete with HRESP=0/HREADY_OUT=1.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_008 steps 1-5 — three word writes covering the low,
//     mid (MSB-set) and high 32-bit address boundaries; PADDR must equal HADDR
//     with no truncation and PWDATA must equal HWDATA for each transfer.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — three fixed boundary-address single word writes.
// =============================================================================

class ahb_mst_test_main_datapath_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_008_seq)

  // Boundary addresses paired with the data each transfer carries.
  localparam int unsigned NUM_BND = 3;

  function new(string name = "ahb_mst_test_main_datapath_008_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] bnd_addr [NUM_BND];
    logic [31:0] bnd_data [NUM_BND];
    int unsigned i;

    // Boundary table — address paired with the data it carries.
    bnd_addr[0] = 32'h0000_0000;  bnd_data[0] = 32'h1111_1111;  // lowest address
    bnd_addr[1] = 32'h8000_0000;  bnd_data[1] = 32'h2222_2222;  // mid / MSB set
    bnd_addr[2] = 32'hFFFF_FFFC;  bnd_data[2] = 32'h3333_3333;  // highest aligned word

    `uvm_info("DP008_SEQ",
      "Starting TEST_MAIN_DATAPATH_008: three boundary-address word writes (address range translation)",
      UVM_MEDIUM)

    // ── Drive each boundary address as a SINGLE word NONSEQ write ────────────
    // The bridge must propagate HADDR->PADDR with no truncation or bit drop and
    // HWDATA->PWDATA bit-exactly for each boundary, completing every write with
    // HRESP=0.
    for (i = 0; i < NUM_BND; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp008_wr_%0d", i));
      start_item(req);
      req.addr       = bnd_addr[i];  // HADDR boundary under test
      req.write      = 1'b1;         // HWRITE=1 (write)
      req.wdata      = bnd_data[i];  // HWDATA
      req.trans_type = 2'b10;        // HTRANS=NONSEQ (new transfer)
      req.burst      = 3'b000;       // HBURST=SINGLE
      req.size       = 3'b010;       // HSIZE=word (32-bit)
      `uvm_info("DP008_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x%08h HWDATA=0x%08h", i, bnd_addr[i], bnd_data[i]),
        UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP008_SEQ", "TEST_MAIN_DATAPATH_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_008_seq
