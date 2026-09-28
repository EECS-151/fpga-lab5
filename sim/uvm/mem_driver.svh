//=========================================================================
// mem_driver: sends packets into rx_fifo and empties tx_fifo
//-------------------------------------------------------------------------
// Two processes run in parallel:
//   * send_packets() takes each mem_txn from the sequencer and pushes its
//     bytes into rx_fifo, waiting out the idle/gap cycles and waiting
//     whenever rx_fifo is full.
//   * drain_tx() pops every byte your memory controller echoes into
//     tx_fifo, after a random delay set by mem_env_cfg.
// Drive on falling edges so inputs are stable when the FIFOs sample them
// on rising edges.
//

class mem_driver extends uvm_driver #(mem_txn);
  `uvm_component_utils(mem_driver)

  mem_vif     vif;
  mem_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(mem_vif)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "mem_driver: no virtual interface set for 'vif'")
    if (!uvm_config_db#(mem_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "mem_driver: no mem_env_cfg set for 'cfg'")
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.rx_wr_en <= 1'b0;
    vif.rx_din   <= '0;
    vif.tx_rd_en <= 1'b0;
    @(negedge vif.clk iff !vif.rst);
    fork
      send_packets();
      drain_tx();
    join
  endtask

  // Wait `gap` cycles with rx_wr_en low, then offer one byte and hold it
  // until rx_fifo accepts it (a rising edge with rx_wr_en high and
  // rx_full low).
  protected task push_byte(bit [7:0] b, int unsigned gap);
    repeat (gap) begin
      vif.rx_wr_en <= 1'b0;
      @(negedge vif.clk);
    end
    vif.rx_wr_en <= 1'b1;
    vif.rx_din   <= b;
    do @(posedge vif.clk); while (vif.rx_full);
    // Drop wr_en at the next negedge. If the next byte has no gap, it is
    // re-asserted in this same time step and the last assignment wins.
    @(negedge vif.clk);
    vif.rx_wr_en <= 1'b0;
  endtask

  protected task send_packets();
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("DRV", {"sending ", req.convert2string()}, UVM_HIGH)
      push_byte(req.cmd, req.idle_cycles);
      push_byte(req.addr, req.gap_addr);
      if (req.cmd == MEM_WRITE)
        push_byte(req.data, req.gap_data);
      seq_item_port.item_done();
    end
  endtask

  // Pop tx_fifo whenever it is not empty, after a random delay.
  protected task drain_tx();
    int unsigned delay;
    forever begin
      @(negedge vif.clk);
      vif.tx_rd_en <= 1'b0;
      if (!vif.tx_empty) begin
        delay = $urandom_range(cfg.tx_delay_max, cfg.tx_delay_min);
        repeat (delay) @(negedge vif.clk);
        vif.tx_rd_en <= 1'b1;
      end
    end
  endtask

endclass
