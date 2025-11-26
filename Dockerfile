FROM nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PYTHONUNBUFFERED=1

# ---- OS まわり ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-dev python3-pip python3-setuptools python3-wheel \
    git wget curl ca-certificates \
    ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# python / pip エイリアス
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --no-cache-dir --upgrade pip

WORKDIR /workspace

# ---- PyTorch (GPU) ----
RUN pip install --no-cache-dir \
    torch==1.9.1+cu111 \
    torchvision==0.10.1+cu111 \
    torchaudio==0.9.1 \
    -f https://download.pytorch.org/whl/torch_stable.html

# ---- mmcv-full ----
# CUDA 11.1 + torch1.9 用のプリビルトを利用
# 1.x.0 用にビルドされた mmcv は 1.x.1 でも通常そのまま使えると公式に書かれている
RUN pip install --no-cache-dir \
    "mmcv-full==1.5.3" \
    -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.9.0/index.html

# ---- MotionDiffuse 本体 ----
COPY . /workspace/MotionDiffuse
WORKDIR /workspace/MotionDiffuse/text2motion

# utilsを見つける
ENV PYTHONPATH=/workspace/MotionDiffuse/text2motion

# NumPy を古いコード互換のあるバージョンに固定
RUN pip install --no-cache-dir "numpy<1.24"

# spaCy のバージョンを Python3.8 対応の 3.7.4 に固定してから依存解決
RUN sed -i 's/^spacy$/spacy==3.7.4/' requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

CMD ["bash"]
