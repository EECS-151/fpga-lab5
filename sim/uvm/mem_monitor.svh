//=========================================================================
// mem_monitor: turns FIFO pin activity back into packets
//-------------------------------------------------------------------------
// Watches the two FIFO interfaces the testbench uses:
//   * rx side: collects bytes as rx_fifo accepts them, and publishes one
//     mem_txn on req_ap for each complete packet
//   * tx side: publishes one mem_txn on rsp_ap (only rdata and saw_tx_full
//     are meaningful) for each byte popped from tx_fifo
// Receivers share each handle through write(); a receiver must clone a
// transaction before modifying it.
//

class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)

  mem_vif vif;
  uvm_analysis_port #(mem_txn) req_ap;
  uvm_analysis_port #(mem_txn) rsp_ap;

  // One flag per read that has entered rx_fifo but whose echo has not been
  // popped yet: was tx_fifo ever full while it waited?
  protected bit tx_full_seen[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_ap = new("req_ap", this);
    rsp_ap = new("rsp_ap", this);
    if (!uvm_config_db#(mem_vif)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "mem_monitor: no virtual interface set for 'vif'")
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_txn      t, r;
    bit [7:0]    bytes[$];         // bytes of the packet being collected
    int unsigned since_last = 0;   // cycles since the last accepted byte
    int unsigned gaps[3];          // idle cycles before each byte
    bit          have_prev = 0;
    mem_cmd_e    last_cmd;
    bit [7:0]    last_addr;
    bit          pop_pending = 0;  // popped last cycle; tx_dout valid now

    forever begin
      @(posedge vif.clk);
      if (vif.rst) begin
        bytes.delete();
        tx_full_seen.delete();
        since_last  = 0;
        pop_pending = 0;
        have_prev   = 0;
        continue;
      end

      if (vif.ctrl_tx_full)
        foreach (tx_full_seen[i]) tx_full_seen[i] = 1'b1;

      //--- tx side: tx_fifo's dout is valid the cycle after the pop
      if (pop_pending) begin
        r = mem_txn::type_id::create("rsp");
        r.cmd   = MEM_READ;
        r.rdata = vif.tx_dout;
        if (tx_full_seen.size() != 0) r.saw_tx_full = tx_full_seen.pop_front();
        `uvm_info("MON", $sformatf("saw echo %0d", r.rdata), UVM_HIGH)
        rsp_ap.write(r);
      end
      pop_pending = vif.tx_rd_en && !vif.tx_empty;

      //--- rx side
      if (vif.rx_wr_en && !vif.rx_full) begin
        gaps[bytes.size()] = since_last;
        bytes.push_back(vif.rx_din);
        since_last = 0;

        if (bytes[0] != MEM_READ && bytes[0] != MEM_WRITE) begin
          `uvm_warning("MON", $sformatf("byte %0d is not a command; the packet format only defines 48 and 49",
                                        bytes[0]))
          bytes.delete();
        end else if ((bytes.size() == 2 && bytes[0] == MEM_READ) ||
                     (bytes.size() == 3)) begin
          t = mem_txn::type_id::create("req");
          t.cmd          = mem_cmd_e'(bytes[0]);
          t.addr         = bytes[1];
          t.data         = (t.cmd == MEM_WRITE) ? bytes[2] : '0;
          t.idle_cycles  = gaps[0];
          t.gap_addr     = gaps[1];
          t.gap_data     = (t.cmd == MEM_WRITE) ? gaps[2] : 0;
          t.back_to_back = have_prev && (gaps[0] == 0);
          t.has_prev     = have_prev;
          t.prev_cmd     = last_cmd;
          t.prev_addr    = last_addr;
          `uvm_info("MON", {"saw packet ", t.convert2string()}, UVM_HIGH)
          if (t.cmd == MEM_READ) tx_full_seen.push_back(vif.ctrl_tx_full);
          req_ap.write(t);
          have_prev = 1;
          last_cmd  = t.cmd;
          last_addr = t.addr;
          bytes.delete();
        end
      end else begin
        since_last++;
      end
    end
  endtask

endclass
