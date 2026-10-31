# Underground View in Line Design — Transport Fever 3 路線規劃地下檢視

模組 ID：`underground_line_design`

路線管理看不到也點不到地下車站與隧道。這個模組在開著路線管理時，於畫面右上角顯示建造工具的「地下 是／否」開關，也能用建造工具的地下切換鍵（預設 G）切換。打開後地面刷白，顯示地下車站、站牌與軌道，路線與車輛照樣上色。狀態在同一次遊戲期間保留。

## 原因

以下檔案都在遊戲的 `base/content/gui.zip`：

- 建造工具的地下開關由 `gui/construction/construction_react_util.tl` 的 `makeUndergroundParam` 建立，打開時把 `LayerConfig.undergroundMode` 設為 true，並以 `makeWhiteScreen` 把地面刷白。按鍵是 input action `IA_UNDERGOUND_MODE_TOGGLE`（原版拼法）。
- 路線管理的五個模式（`gui/line_vehicle_mgmt/manager_window.tl` 的 main、segment、move stop、move waypoint、send vehicles）都呼叫 `line_util.makeLineActionDescriptor`（`gui/line_vehicle_mgmt/line_util.tl`）。它每次新建一個 `LayerConfig`，從不設 `undergroundMode`。

## 實作

模組沒有 game script，只用 `react-replacement-config` 資源在 GUI 載入時執行 `doReplaceFn`，見 [replacement.res.lua](content/gui/underground_line_design/replacement.res.lua)。

[replacement.script.tl](content/gui/underground_line_design/replacement.script.tl) 包裝三個欄位：

| 欄位 | 改動 |
|---|---|
| `line_util.makeLineActionDescriptor` | 以 `useStepState` 讀開關狀態，切換時重繪該模式；掛載與卸載時計數，有模式掛載時顯示開關視窗；執行原函式期間標記「在路線模式內」 |
| `builtin.LayerConfig` | 在路線模式內、開關打開時，先對傳入的 `config` 呼叫 `underground.apply`，再呼叫原版 |
| `builtin.Window` | 路線管理視窗（id `menu.management`）的 `inputActionBubbleUpFilter` 換成原版清單加上 `IA_UNDERGOUND_MODE_TOGGLE` |

`LayerConfig` 在原函式裡建立，包裝層拿不到，所以改在它交給 `builtin.LayerConfig` 時修改。路線管理視窗的按鍵放行清單是 C++ 物件，讀不到也改不了（`no writable member`），只能在模組裡抄一份 `manager_window.tl` 的清單；遊戲改版改了這份清單時要跟著更新。

[underground.tl](content/gui/underground_line_design/underground.tl)：

- `apply`：設 `undergroundMode = true`，只換掉 `colorPassFn.fallbackColor`（建造工具的刷白色）。`makeWhiteScreen` 會換掉整個 `colorPassFn`，路線車輛的上色也會消失，所以不用它。
- 開關視窗：`compact`、不可移動、不可關閉的 `builtin.Window`，id `undergroundline.bar`，第一個路線模式掛載時加入視窗容器，之後依掛載中的模式數量以 `api.gui.byId.setVisible` 顯示或隱藏。內容是「地下」標籤與 `"Horizontal"` 版面的 `ToggleButtonGroup`，文字取自 `makeUndergroundParam`。
- 按鍵：開關視窗以 `react.useInputAction` 註冊 `IA_UNDERGOUND_MODE_TOGGLE`，只在路線管理開著時有效。
- Esc：視窗容器把 Esc（`IA_CLOSE_TOPMOST_WINDOW`）送給最上層的視窗。開關視窗顯示後與點擊後，以 `moveSingletonWindowToFront(manager_window.ManagerToolWindow)` 把路線管理移回最上層。

[underground_line_design.css.lua](content/gui/underground_line_design/underground_line_design.css.lua)：開關視窗固定在右上角（`anchorPoint`、`gravity` 為 `{1, 0}`，距上 80、距右 20），寬 314，背景與外框照建造工具底部列。

## 試過但不可行的做法

- **左下角的開關**：照建造工具放在左下角時，被路線管理視窗擋住，改放右上角。
- **原版參數按鈕組**：`script_param_util.buildScriptParamCompSimple` 的按鈕用 `"Uniform"` 版面平分可用寬度，放在依內容決定大小的視窗裡寬度為 0，只看得到標籤。
- **CSS 選擇器的 id**：視窗 id 用 `underground_line_design.bar` 時，`Window#id` 規則沒有作用；改成不含底線的 `undergroundline.bar` 後才套用。
- **在路線模式或路線管理視窗內容接按鍵**：在 `makeLineActionDescriptor` 裡、或替換 `manager_window.ManagerWindowContent` 後呼叫 `react.useInputAction`，都收不到 G。掛在 `ModEntryPointExtension` 的元件也收不到。只有開關視窗收得到。
- **`builtin.SimpleInputActions`**：型別定義裡有，`builtin.lua` 與遊戲本體都沒有實作。
- **右下角的按鍵提示**：提示列由 CSS 的 `actionPromptList` 決定。`R::ManagerWindowContent!actionMain` 等選擇器、`!action-management`、`#mainView!tool-Manager` 都試過，提示沒有出現，暫不處理。

## 開發

- 語言：Teal `.tl`。型別定義取自遊戲的 `api/tealdef`、`base/tealdef` 與本模組的 [tealdef/](tealdef/)。
- 型別檢查：`powershell -ExecutionPolicy Bypass -File tools\check.ps1`，`tl` 0.24.7 需在 PATH 中。
- 部署：`powershell -ExecutionPolicy Bypass -File tools\deploy.ps1`，預設複製到 staging area；`-Target Mods` 改為 `local\mods`，`-Remove` 移除。
- 遊戲 log 以 `[underground_line_design]` 篩選。
