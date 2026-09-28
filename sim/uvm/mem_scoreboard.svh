//=========================================================================
// mem_scoreboard: checks every echoed byte against a reference model
//-------------------------------------------------------------------------
// Receives complete packets from the monitor's req_ap and echoed bytes
// from its rsp_ap. The memory controller handles packets one at a time,
// in the order they enter rx_fifo, so the model applies them in that same
// order, and the oldest outstanding read belongs to each echo that arrives.
//
// Your memory starts uninitialized, so a read of an address that has never
// been written returns X. Such reads are counted as "unchecked": they are
// neither passes nor failures, and they do not count toward coverage.
//
// Every write, and every read whose echo matched, is published on
// checked_ap for the coverage subscriber.
//

// Two write() methods in one class need distinct names; these macros
// declare analysis imps that call write_req() and write_rsp().
`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_rsp)

class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp_req #(mem_txn, mem_scoreboard) req_export;
  uvm_analysis_imp_rsp #(mem_txn, mem_scoreboard) rsp_export;
  uvm_analysis_port    #(mem_txn)                 checked_ap;

  // Reference model: what each address should hold.
  protected bit [7:0]    model   [256];
  protected bit          written [256];

  // Reads waiting for their echo, and (in parallel) the value each one must
  // return. The value is taken from the model when the read ENTERS rx_fifo:
  // a later write to the same address must not change it.
  protected mem_txn      pending[$];
  protected bit [7:0]    expected[$];
  protected bit          checkable[$];
  protected int unsigned outstanding;  // == pending.size(), waitable
  protected int unsigned n_writes;
  protected int unsigned n_pass;
  protected int unsigned n_fail;
  protected int unsigned n_unchecked;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_export = new("req_export", this);
    rsp_export = new("rsp_export", this);
    checked_ap = new("checked_ap", this);
  endfunction

  virtual function void write_req(mem_txn t);
    if (t.cmd == MEM_WRITE) begin
      model[t.addr]   = t.data;
      written[t.addr] = 1'b1;
      n_writes++;
      checked_ap.write(t);
    end else begin
      pending.push_back(t);
      expected.push_back(model[t.addr]);
      checkable.push_back(written[t.addr]);
      outstanding = pending.size();
    end
  endfunction

  virtual function void write_rsp(mem_txn r);
    mem_txn   req;
    mem_txn   done;
    bit [7:0] exp;
    bit       check;

    if (pending.size() == 0) begin
      `uvm_error("SB_UNEXPECTED", $sformatf("echo %0d arrived with no outstanding read", r.rdata))
      return;
    end
    req         = pending.pop_front();
    exp         = expected.pop_front();
    check       = checkable.pop_front();
    outstanding = pending.size();

    if (!check) begin
      n_unchecked++;
      `uvm_info("SB_UNCHECKED", $sformatf("read of never-written addr %0d; echo not checked", req.addr),
                UVM_MEDIUM)
      return;
    end

    if (r.rdata !== exp) begin
      n_fail++;
      `uvm_error("SB_MISMATCH", $sformatf("read addr %0d: expected %0d, DUT echoed %0d",
                                          req.addr, exp, r.rdata))
      return;
    end

    n_pass++;
    `uvm_info("SB_MATCH", $sformatf("read addr %0d = %0d", req.addr, r.rdata), UVM_HIGH)
    $cast(done, req.clone());
    done.rdata       = r.rdata;
    done.saw_tx_full = r.saw_tx_full;
    checked_ap.write(done);
  endfunction

  // Blocks until every read has been answered.
  virtual task wait_for_drain();
    wait (outstanding == 0);
  endtask

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (pending.size() != 0)
      `uvm_error("SB_UNANSWERED", $sformatf("%0d read(s) were never echoed; oldest: addr=%0d",
                                            pending.size(), pending[0].addr))
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB_SUMMARY", $sformatf("%0d write(s) sent; %0d read(s) checked: %0d passed, %0d failed; %0d unchecked",
                                      n_writes, n_pass + n_fail, n_pass, n_fail, n_unchecked), UVM_NONE)
  endfunction

endclass
