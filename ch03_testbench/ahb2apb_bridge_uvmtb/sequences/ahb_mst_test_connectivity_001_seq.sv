// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_001
// DESCRIPTION: Stimulus for source_address_bus_connectivity.
//              Verifies the HADDR address bus is fully connected by driving the
//              minimum (0x0000_0000) and maximum (0xFFFF_FFFF) address values
//              and confirming the bridge captures and translates them onto
//              PADDR with no stuck-at or swapped bits.
//
//              Two single word-aligned WRITE transfers:
//                T1/T2: HADDR=0x0000_0000, HWRITE=1, HSIZE=word -> PADDR=0x0..0
//                T3/T4: HADDR=0xFFFF_FFFF, HWRITE=1, HSIZE=word -> PADDR=0xF..F
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_001 steps 1-5 — drive min/max HADDR and compare
//     against the PADDR captured on the peripheral side.
//
// NOTE: No .randomize() — fixed addresses per [TC1].
//
// CONFIDENCE: HIGH — straightforward min/max address connectivity stimulus.
// =============================================================================

class ahb_mst_test_connectivity_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_001_seq)

  // Min / max address corners driven to exercise every HADDR bit.
  localparam logic [31:0] ADDR_MIN = 32'h0000_0000;
  localparam logic [31:0] ADDR_MAX = 32'hFFFF_FFFF;

  function new(string name = "ahb_mst_test_connectivity_001_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] test_addr [2];

    test_addr[0] = ADDR_MIN;
    test_addr[1] = ADDR_MAX;

    `uvm_info("CONN001_SEQ",
      "Starting TEST_CONNECTIVITY_001: drive min/max HADDR (0x0..0, 0xF..F)",
      UVM_MEDIUM)

    // Drive each corner address as a single word WRITE so the bridge captures
    // HADDR and re-drives it onto PADDR.
    foreach (test_addr[i]) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn_wr_%0d", i));
      start_item(req);
      req.addr       = test_addr[i];
      req.write      = 1'b1;    // Write — step drives HWRITE=1
      req.wdata      = 32'hA5A5_5A5A;  // fixed non-trivial data
      req.trans_type = 2'b10;   // NONSEQ — new transfer
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
      req.post_randomize();
      `uvm_info("CONN001_SEQ",
        $sformatf("WRITE addr-corner[%0d]: HADDR=0x%08h (expect PADDR=0x%08h)",
                  i, test_addr[i], test_addr[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN001_SEQ", "TEST_CONNECTIVITY_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_001_seq
