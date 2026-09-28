//=========================================================================
// Staff sequences
//-------------------------------------------------------------------------
// A sequence creates, randomizes and sends a stream of mem_txns. The
// driver consumes one per start_item()/finish_item() pair.
//

// num_items random packets using the default constraints of mem_txn.
// Reads only go to addresses this sequence has already written, so every
// read can be checked. (The first packet is therefore always a write.)
class mem_rand_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_rand_seq)

  int unsigned num_items = 10;

  protected bit [7:0] written[$];

  function new(string name = "mem_rand_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn t;
    repeat (num_items) begin
      t = mem_txn::type_id::create("t");
      start_item(t);
      if (!t.randomize() with {
            written.size() == 0 -> cmd == MEM_WRITE;
            cmd == MEM_READ     -> addr inside {written};
          })
        `uvm_error("RAND", "mem_rand_seq: randomize() failed")
      if (t.cmd == MEM_WRITE && !(t.addr inside {written}))
        written.push_back(t.addr);
      finish_item(t);
    end
  endtask
endclass
