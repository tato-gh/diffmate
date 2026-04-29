# diffmate

`diffmate` は、git diff を監視して、変更内容を LLM app-server に送り、応答を返すツールです。

`DIFFMATE.md` を置いたプロジェクトで起動し、作業中の差分を会話の入力として扱います。

## 目的

開発中のファイル変更を会話の入力として扱い、差分が発生するたびに LLM から反応を得ます。

想定する使い方:

1. 対象プロジェクトで `diffmate` を起動する
2. `poll_interval` ごとに `git diff` を取得する
3. 初回は全 diff、以降は前回 diff からの差分だけを LLM app-server に送る
4. LLM の応答をターミナルへ表示する
5. `Ctrl+C` まで繰り返す

## チュートリアル

### 1. diffmate をビルドする

```bash
cd /path/to/diffmate
mix deps.get
mix build
```

ビルド後、実行ファイルは `bin/diffmate.escript` に作られます。

### 2. 対象プロジェクトに設定ファイルを置く

`git diff` を監視したいプロジェクトに `DIFFMATE.md` を作ります。

```bash
cd /path/to/your-project
cp /path/to/diffmate/DIFFMATE.md.example DIFFMATE.md
```

必要に応じて `DIFFMATE.md` の `prompt` を変更します。

### 3. diffmate を起動する

別ターミナルで、対象プロジェクトを指定して起動します。

```bash
/path/to/diffmate/bin/diffmate.escript /path/to/your-project
```

`DIFFMATE.md` のパスを直接指定しても起動できます。

```bash
/path/to/diffmate/bin/diffmate.escript /path/to/your-project/DIFFMATE.md
```

### 4. 変更を作って反応を見る

対象プロジェクト側でファイルを変更します。

```bash
echo "hello" >> README.md
```

`poll_interval` 後に、diffmate 側のターミナルへ LLM の応答が表示されます。終了するときは `Ctrl+C` を押します。

### 5. 直接メッセージを送る

diffmate 起動中のターミナルへ通常の文章を入力すると、そのまま LLM に送信されます。

```text
この変更のリスクを短く見て
```

特別なコマンド:

- `/clear`: 現在の thread をリセットします。
- `/compact`: 現在の会話を要約して、新しい thread に引き継ぎます。

## 振る舞い

- `git diff` の定期監視
- 未追跡ファイルを含めるオプション
- `DIFFMATE.md` の front matter 読み込み
- diff が空になった時の thread reset
- prompt 変更時の thread reset
- `/clear` による thread reset
- `/compact` による要約引き継ぎ
- 標準入力テキストの直接送信
- app-server の approval request への非対話応答
- dynamic tool call の不許可応答

## 設定

設定ファイル名は `DIFFMATE.md` です。front matter のトップレベルに設定を書きます。

```yaml
---
command: "codex app-server"
diff_command: "git diff HEAD"
poll_interval: 1000
include_untracked: false
approval_policy: "never"
thread_sandbox: "read-only"
turn_sandbox_policy:
  type: "readOnly"
  networkAccess: false
prompt: |
  ファイルの変更を見て、気軽に一言コメントしてください。
---
```

補足:

- `diff_command` は対象プロジェクトのルートで実行され、末尾に `-- .` が付与されます。コマンドが失敗した場合は warning を出し、その回の diff 反映は行いません。
- `include_untracked: true` の場合、未追跡ファイルも追加 diff として送ります。意図しないファイル内容が送られないように注意してください。
- approval request は非対話で応答します。`approval_policy: "always"` の場合だけ承認し、それ以外では拒否します。
- `DIFFMATE.md` 自身の変更は diff 入力から除外します。
