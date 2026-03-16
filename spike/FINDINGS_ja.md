---
title: Peregrine スパイク調査結果
last_updated: 2026-03-17
tags:
  - peregrine
  - spike
---

# Issue #4 スパイク結果まとめ

## 目的

Lean4 → LambdaBox → Rust → RISC-0 のパイプラインが動くか検証する。

## 結論：Rust パスは現時点で不可

| 項目 | 結果 |
|------|------|
| lean-to-lambdabox で `.ast` 生成 | ✅ 成功 |
| peregrine で `.ast` → Rust 変換 | ❌ **失敗** |
| peregrine で `.ast` → C 変換 | ✅ 成功 |
| RISC-0 ゲストでの実行 | ⏭ 未到達 |

## 失敗の原因

- peregrine の **Rust バックエンド**は **typed IR（.tast）** を要求する
- lean-to-lambdabox は **untyped IR（.ast）** しか出力できない
- この 2 つのギャップを埋める手段が現時点では存在しない

## 動いたもの

- C / OCaml バックエンドは untyped `.ast` を受け付け、正常にコード生成できた
- カスタムバイト型（`Bit`, `Byte`, `ByteList`）は `#erase` で問題なく `.ast` に変換できた

## 次のステップの選択肢

1. **lean-to-lambdabox に typed IR 出力を追加する**（高難度・upstream 改修）
2. **C バックエンドで生成した C コードを riscv32im にクロスコンパイルする**（GC ランタイムの移植が必要）
3. **upstream に enhancement request を出す**（タイムライン不明）
4. **Lean4 のネイティブ C バックエンドで直接 riscv32im にコンパイルする**（peregrine をスキップ）
