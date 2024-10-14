## 心得
借鏡前人的智慧，雖然此次performance的面積是平方，還是建議追latency，在有限的範圍下使用register能大幅縮小存取時間
可以想一下怎麼處理SRAM，包括擺什麼資料、怎麼擺、如何存取

> [!TIP]
> 存gray scale而不是RGB
> SRAM資料交叉擺放，增加讀取速度
> 將資料load到register上，加速運算
> 多的register空間可以拿來存4x4、8x8 gray scale
