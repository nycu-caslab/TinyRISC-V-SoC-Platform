// Hazard_Unit.v
// 專為 Decoupled Backend 設計的管線控制中樞
module Hazard_Unit(
    // 來自 Frontend Queue 的狀態
    input  wire inst_rdy_i,      // Queue 裡面有指令可拿
    
    // 來自 EX Stage 的狀態
    input  wire EX_start,        // EX 正在執行有效指令
    input  wire EX_done,         // EX 該指令執行完畢
    input  wire br_taken,        // 發生 Branch / Jump
    input  wire fetch_invalid_i, // 發生 fence.i (需要 flush)

    // 控制 Frontend 的訊號
    output wire req_inst_o,      // Pop Queue (拿取下一個指令)
    output wire redirect_valid_o,// 通知前端清空 Queue 並跳轉

    // 控制 Pipeline Registers (ID, EX, WB)
    output wire ID_en,
    output wire ID_clear,
    output wire EX_en,
    output wire EX_clear,
    output wire WB_en,
    output wire WB_clear
);

    // ==========================================
    // 1. Stall 邏輯 (管線暫停)
    // ==========================================
    // 只要 EX 正在忙碌 (start 但還沒 done)，就必須卡住前半段
    wire stall = EX_start && !EX_done;

    // ==========================================
    // 2. Queue 進料邏輯 (握手)
    // ==========================================
    // Queue 裡面有東西 (inst_rdy_i) 且 Backend 沒有塞車 (!stall) 時，才拿新指令
    assign req_inst_o = inst_rdy_i && !stall;

    // ==========================================
    // 3. Register Enable 邏輯
    // ==========================================
    assign ID_en = !stall; // 塞車時，ID Register 鎖住，保持當前指令
    assign EX_en = !stall; // EX Register 也鎖住，等到底下硬體做完
    assign WB_en = 1'b1;   // WB 永遠可以前進 (它不會 stall)

    // ==========================================
    // 4. Flush 邏輯 (沖刷與氣泡)
    // ==========================================
    wire flush_req = br_taken || fetch_invalid_i;
    
    // 向前端發出跳轉/失效請求
    assign redirect_valid_o = flush_req;

    // 如果發生跳轉，代表剛進入 ID 的指令是錯誤路徑抓來的，必須清除
    assign ID_clear = flush_req; 
    
    // EX 本身就是產生 Branch 的地方，它要順利走到 WB，所以不需要清掉它自己
    assign EX_clear = 1'b0;      
    
    // 當 EX 發生 stall 時，因為它還沒做完，不能把未完成的垃圾寫入 WB。
    // 因此在 stall 期間，強行給 WB 塞入氣泡 (clear)
    assign WB_clear = stall;

endmodule