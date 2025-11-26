# docker-MotionDiffuse

このリポジトリは、元の [MotionDiffuse](https://github.com/mingyuan-zhang/MotionDiffuse) を **Docker でそのまま動かせるようにしたもの**です。  
RTX 4090（Ada）+ Windows 11 + Docker Desktop + NVIDIA Container Toolkit で動作確認しています。

## Docker イメージの構成

以下のような環境を構築します。

- ベース: `nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04`
- Python: 3.8
- PyTorch: `1.9.1+cu111`
- torchvision: `0.10.1+cu111`
- torchaudio: `0.9.1`
- mmcv-full: `1.5.3` (cu111 / torch1.9 対応ビルド)
- NumPy: `<1.24`（古いコードの `np.float` などに対応するため固定）
- spaCy: `3.7.4`（Python 3.8 対応の最終バージョン）
- そのほか `text2motion/requirements.txt` に記載された依存関係

`PYTHONPATH` は

```bash
/workspace/MotionDiffuse/text2motion
```

に通してあるので、コンテナ内では `python tools/xxx.py` で `utils` などが読み込めます。

## 前提条件

ホスト側に以下が入っていることを前提にしています。

- NVIDIA GPU（RTX 4090 で確認）
- NVIDIA ドライバ（Docker の GPU コンテナが動くもの）
- Docker / Docker Desktop
- NVIDIA Container Toolkit（`--gpus all` が使える状態）

## セットアップ

### 1. リポジトリのクローン

ホスト側で:

```bash
cd ~/cloneGit
git clone <URL> MotionDiffuse
cd MotionDiffuse
```


### 2. データセットとチェックポイントを配置

オリジナルの `text2motion/install.md` 内 `Data Preparation` に従って、`text2motion/` 以下に配置してください。

- データ: `text2motion/data/`
- チェックポイント: `text2motion/checkpoints/`

例:

```bash
MotionDiffuse/
  text2motion/
    data/
      HumanML3D/ など
    checkpoints/
      t2m/
        t2m_motiondiffuse/
          opt.txt
          xxx.tar  ...
```

### 3. 出力ディレクトリの作成

生成された GIF などを出す場所として `output/` を作っておきます。

```bash
cd ~/cloneGit/MotionDiffuse
mkdir -p output
```

## 4. Docker イメージのビルド

リポジトリのルートで:

```bash
cd ~/cloneGit/MotionDiffuse
docker build -t motiondiffuse .
```

---

## コンテナの起動

### Linux / WSL / PowerShell の場合

単純にカレントディレクトリをそのままマウントします。

```bash
cd ~/cloneGit/MotionDiffuse

docker run --gpus all --ipc=host -it --rm \
  -v "$PWD:/workspace/MotionDiffuse" \
  motiondiffuse
```

### Windows + Git Bash の場合（PATH 変換対策）

Git Bash は docker.exe に渡す引数を勝手に Windows パスに変換しようとするため、そのまま `-v "$PWD:..."` を使うとパスがおかしくなることがあります。  
その対策として、環境変数 `MSYS_NO_PATHCONV=1` を付けて起動します。

```bash
cd ~/cloneGit/MotionDiffuse

MSYS_NO_PATHCONV=1 docker run --gpus all --ipc=host -it --rm \
  -v "$PWD:/workspace/MotionDiffuse" \
  motiondiffuse
```

これにより

- ホスト: `~/cloneGit/MotionDiffuse`
- コンテナ: `/workspace/MotionDiffuse`

が 1:1 でマウントされます。

## 推論サンプル（GIF 生成）

以下は `tools/visualization.py` を使って、テキストから 1 本のモーションを生成して GIF を吐き出す例です。

1. コンテナ内で以下を実行:

```bash
cd /workspace/MotionDiffuse/text2motion

# 念のため（すでにホスト側で作っていれば何も起こらない）
mkdir -p /workspace/MotionDiffuse/output

PYTHONPATH=. python tools/visualization.py \
  --opt_path checkpoints/t2m/t2m_motiondiffuse/opt.txt \
  --text "a person is dancing happily" \
  --motion_length 60 \
  --result_path /workspace/MotionDiffuse/output/test_sample.gif \
  --gpu_id 0
```

- `--motion_length` はフレーム数（論文通り 196 フレーム以下）
- `--gpu_id 0` は `cuda:0` を使う設定
- `--result_path` はホスト側の `MotionDiffuse/output/test_sample.gif` と 1:1 で対応

2. ホストに戻って確認:

```bash
cd ~/cloneGit/MotionDiffuse
ls output
# test_sample.gif があれば OK
```

---

## トレーニングやその他スクリプトの実行

基本的には、元の MotionDiffuse の README に書かれているコマンドを **`/workspace/MotionDiffuse/text2motion` でそのまま実行**すれば動きます。

例:

```bash
cd /workspace/MotionDiffuse/text2motion

PYTHONPATH=. python tools/train_t2m_motiondiffuse.py \
  --config options/t2m/t2m_motiondiffuse.yaml \
  --gpu_id 0
```

など。

- `PYTHONPATH=.` は Dockerfile 側で `ENV PYTHONPATH=/workspace/MotionDiffuse/text2motion` を設定しているので、省略しても動くはずですが、明示しておいた方がわかりやすいです。
- ログやチェックポイントの実際の出力位置は、オリジナルコードの設定・引数に従います。


---

## 既知の注意点

- コンテナ内は **古い PyTorch / CUDA / NumPy** の組み合わせになっています。
  - これは元コードが `numpy.float` などの古い API を前提にしているためです。
  - ホストのグローバル環境で同じスクリプトを動かすときは、`numpy>=2.0` などを入れると `AttributeError: module 'numpy' has no attribute 'float'` になるので注意してください（コンテナ内では `numpy<1.24` に固定してあります）。

- RTX 4090（Ada）では、CUDA 11.1 のバイナリはネイティブに sm_89 をサポートしていませんが、Ampere 向けのバイナリ互換により普通に実行できます。
  - 性能チューニングより「元コードが壊れずに動く」ことを優先して、この構成にしてあります。

---

## ライセンス

元の MotionDiffuse のライセンスに従います。  
このリポジトリの追加部分（Dockerfile など）も、特に断りがなければ同じライセンスで扱ってください。

