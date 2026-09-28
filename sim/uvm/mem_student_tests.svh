//=========================================================================
// Add your sequences and tests here.
//-------------------------------------------------------------------------
// This file is included at the end of mem_uvm_pkg, so everything above it
// (mem_txn, mem_rand_seq, mem_base_test, ...) is visible.
//
// Extend mem_base_test and override make_seq() to choose your stimulus.
// Override configure() too if you want tx_fifo backpressure.
//
// Template: uncomment, rename my_* to something descriptive, fill in the
// TODOs, and copy both classes again for each new test.
//
// // 1. A sequence: which packets to send.
// class my_seq extends uvm_sequence #(mem_txn);
//   `uvm_object_utils(my_seq)
//
//   int unsigned num_items = 50;
//
//   function new(string name = "my_seq");
//     super.new(name);
//   endfunction
//
//   virtual task body();
//     mem_txn t;
//     repeat (num_items) begin
//       t = mem_txn::type_id::create("t");
//       start_item(t);
//       // TODO: turn off any default constraint you need to go beyond, e.g.
//       //   t.c_no_gaps.constraint_mode(0);
//       if (!t.randomize() with { /* TODO: your constraints */ })
//         `uvm_error("RAND", "my_seq: randomize() failed")
//       finish_item(t);
//     end
//   endtask
// endclass
//
// // 2. The test: chooses the sequence (and, optionally, the knobs).
// class my_test extends mem_base_test;
//   `uvm_component_utils(my_test)
//
//   function new(string name, uvm_component parent);
//     super.new(name, parent);
//   endfunction
//
//   // Optional: hold echoed bytes in tx_fifo for 0-20 cycles each.
//   // virtual function void configure(mem_env_cfg cfg);
//   //   cfg.tx_delay_max = 20;
//   // endfunction
//
//   virtual function uvm_sequence #(mem_txn) make_seq();
//     my_seq seq = my_seq::type_id::create("seq");
//     return seq;
//   endfunction
// endclass
//
//=========================================================================
