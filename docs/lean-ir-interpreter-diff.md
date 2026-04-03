# Lean `ir_interpreter.cpp` と現在の Rust 実装の差分

対象:

- Lean 本体: `lean4/src/library/ir_interpreter.cpp`
  - https://github.com/leanprover/lean4/blob/master/src/library/ir_interpreter.cpp
- 現在の Rust 実装: `verifiable-stf` 配下の IR trace interpreter

## 結論

現在の Rust 実装は、Lean 本体の IR interpreter をそのまま移植したものではない。
正確には、

- Lean の λRC IR を実行するという発想は引き継いでいる
- ただし実装目的は別で、zk/trace 用にかなり再構成されている
- 特に「忠実な再現」より「トレース生成と後段検証しやすさ」を優先している

そのため、Lean 本体との差分はかなり大きい。

## 1. 目的の差分

### Lean 本体

Lean 本体の `ir_interpreter.cpp` は、Lean の IR を実際に実行するための interpreter。
コメントでも「単純さを優先した IR interpreter」であることが明示されている。

### Rust 実装

Rust 実装の主目的は、IR を実行することに加えて、

- 中間値を保存する
- 操作手順を記録する
- 後段の verifier で検証できる形にする

ことにある。

### 影響

この時点で役割が違うので、Rust 実装は Lean 本体の「実行器」そのものではない。
「IR を動かす」という一点は共通だが、最適化対象も設計判断も異なる。

## 2. 値表現の差分

### Lean 本体

Lean ランタイムの本物の値表現を使う。
boxed/unboxed、オブジェクト、クロージャなどは Lean 実行系の表現そのもの。

### Rust 実装

Rust 独自の `Value` enum を使う。

- `Scalar`
- `Object`
- `Array`
- `ByteArray`
- `Closure`
- `Nat`
- `Str`
- `Irrelevant`

### 忠実に再現できていない点

- Lean ランタイムの実メモリ表現ではない
- boxed/unboxed の本来の扱いをそのまま再現していない
- Lean のランタイム上の不変条件をそのまま持っていない
- closure や object の内部表現は Rust 側の近似モデル

### 影響

Rust 実装は「Lean の本物の値を動かしている」のではなく、
「Lean の値っぽいものを Rust で再構成している」に近い。

## 3. 実行モデルの差分

### Lean 本体

Lean 本体は homogeneous stack を中心とした低レベルな実装で、

- 値スタック
- base pointer
- variable index
- call stack metadata
- join point 用スタック

のような仕組みで回る。

### Rust 実装

Rust 実装はより高水準で、

- `CallFrame`
- `get_var` / `set_var`
- `BodyExecutor`
- `ExprEvaluator`

などの構造体ベースで実装している。

### 忠実に再現できていない点

- 本家のスタック機械をそのまま移していない
- base pointer + slot index 方式ではない
- ランタイム寄りの評価器というより、AST/IR を素直に辿る評価器になっている

### 影響

意味上は近くても、内部の挙動・コスト構造・実装上の前提はかなり異なる。
「Lean 本体と同じ実行機構」とは言えない。

## 4. extern / native function 呼び出しの差分

### Lean 本体

Lean 本体は、可能ならネイティブコード側に切り替える。
コメントでも、シンボル探索を通じて外部関数や native code を呼ぶ説明がある。

### Rust 実装

Rust 実装では、

- primitive は Rust 側で直接実装
- extern は `extern_stubs` に登録したスタブで処理
- 未対応 extern は警告を出して簡略処理する場合がある

### 忠実に再現できていない点

- Lean 本体の native 連携方式を再現していない
- ABI やシンボル解決の仕組みを持っていない
- 「Lean ですでにコンパイル済みのコードを呼ぶ」方向ではない

### 影響

Rust 実装は本家の実行環境との接続が弱い。
必要な extern を人力で stub 化しているため、一般性は低い。

## 5. トレース機構の追加

### Lean 本体

通常の interpreter なので、主眼は「実行結果を得ること」。

### Rust 実装

Rust 実装は追加で以下を持つ。

- `value_table`
- `TraceStep`
- `output_value_id`
- `TraceHeader`
- 出力 hash や step/value count

### 忠実に再現できていない点

これは「再現できていない」というより、目的が別なので大きく拡張されている。
本家には存在しない責務である。

### 影響

Rust 実装は interpreter であると同時に、監査ログ生成器でもある。
そのため設計全体が「検証用に記録しやすいか」に引っ張られている。

## 6. 値保存戦略の差分

### Lean 本体

Lean 本体は runtime の値を使ってその場で実行する。
少なくとも Rust 実装のような「中間値を全件 value table に保存する」発想ではない。

### Rust 実装

現在の Rust 実装は、中間値を `value_table` に都度 clone して積んでいく。

### 忠実に再現できていない点

- 本家のランタイム実行とはまったく別の保存戦略
- 同じ値でも何度も複製して保存する
- トレース都合の人工的なデータ構造が中心になっている

### 影響

巨大な `ByteArray` や `Object` が何度も保存され、サイズが急増する。
これは Lean 本体の interpreter 由来の問題ではなく、Rust 実装独自の問題。

## 7. 検証可能性のための単純化

### Lean 本体

Lean 本体は「Lean として正しく動くこと」が基準。

### Rust 実装

Rust 実装は「あとから verifier が追えること」も基準なので、

- 値に `ValueId` を振る
- 操作を `TraceStep` にする
- 計算過程を後追いできる形にする

という単純化を入れている。

### 忠実に再現できていない点

- 本家の自然な実行状態をそのまま露出していない
- verifier に都合の良い表現へ落とし込んでいる
- 実行モデルより「説明可能な記録モデル」が前面に出ている

### 影響

Rust 実装は本家より「検証のために見やすい」一方で、
Lean 本体そのものの挙動をそのまま写したものではない。

## 8. 意味保存の不完全さ

### Lean 本体

当然ながら、実行に必要な更新は全部その場で処理する。

### Rust 実装

Rust 実装では、実行される更新の一部が trace/verifier に十分に現れていない。

例:

- `USet`
- `SSet`
- `SetTag`

これらは実行されるが、現在の trace/verifier では十分に検証可能な形になっていない。

### 忠実に再現できていない点

- 実行はしても、その意味を完全にはトレース化できていない
- verifier が追える意味と、interpreter が実際にやっている意味にズレがある

### 影響

これは「Lean 本体に対する忠実性」というより、
「Rust 実装の実行意味と検証意味が一致していない」という問題。
特に zk/証明用途では重要。

## 9. 完全性よりワークロード適応を優先している

### Lean 本体

汎用の Lean IR interpreter。

### Rust 実装

特定のワークロードを動かすために、

- ETH2 向け stub
- primitive の個別実装
- 一部 path の簡略化
- `_boxed` 系の特別扱い

などを入れている。

### 忠実に再現できていない点

- Lean 全般をカバーする完全実装ではない
- 必要なケースに合わせた実用寄りの近似
- 本家の汎用 interpreter とは守備範囲が違う

### 影響

「手元の対象 IR を動かす」には十分でも、
Lean 本体の interpreter の代替とは言えない。

## 差分の重要度

### 高

- Lean ランタイムの本物の値表現を使っていない
- native/extern 呼び出し方式を再現していない
- trace/verifier 都合で設計が大きく変わっている
- 一部更新操作が完全には検証可能になっていない

### 中

- スタック機械の実装スタイルが異なる
- 汎用 interpreter ではなく対象ワークロード寄り

### 低

- データ構造や API の細部差分
- 実装言語の違いによる表現差

## まとめ

現在の Rust 実装は、Lean 本体の `ir_interpreter.cpp` の

- 入力が λRC IR である
- IR を辿って評価する
- 関数・primitive・extern を区別する

という骨格はかなり参考にしている。

一方で、以下は忠実再現ではない。

- Lean ランタイムの値表現
- スタック機械としての内部構造
- native/extern 連携
- 汎用 interpreter としての完全性
- 実行意味と検証意味の一致

したがって、この Rust 実装は
「Lean 本体の Rust 移植」ではなく、
「Lean IR interpreter の考え方を借りた、trace/verifier 向けの再設計版」
と説明するのが最も正確。
