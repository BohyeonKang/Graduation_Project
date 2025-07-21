import numpy as np
from pathlib import Path

# 생성할 파일 경로
base_dir = Path("./glb_init")
base_dir.mkdir(exist_ok=True)

# 파일 이름
ifmap_file = base_dir / "ifmap.memh"
weight_file = base_dir / "weight.memh"
psum_file = base_dir / "psum.memh"

# HEX 포맷 설정 (16비트)
bitwidth = 16
fmt = f"{{:0{bitwidth // 4}X}}"  # 예: 04D3

### 1. IFMAP 생성 (5채널, 각 5x5)
ifmap = np.arange(125).reshape(5, 5, 5)  # (channel, row, col)
with ifmap_file.open("w") as f:
    for c in range(5):
        for r in range(5):
            for col in range(5):
                f.write(fmt.format(ifmap[c, r, col]) + "\n")

### 2. WEIGHT 생성 (4 output filter × 5 input channel × 3x3)
weight = np.arange(180).reshape(4, 5, 3, 3)  # (oc, ic, row, col)
with weight_file.open("w") as f:
    for oc in range(4):
        for ic in range(5):
            for r in range(3):
                for col in range(3):
                    f.write(fmt.format(weight[oc, ic, r, col]) + "\n")

### 3. PSUM 생성 (4채널, 각 3x3)
psum = np.array([
    [[21295, 21580, 21865], [26890, 27220, 27550], [33385, 33760, 34135]],
    [[55720, 56680, 57640], [68065, 69070, 70075], [81310, 82360, 83410]],
    [[90145, 91780, 93415], [109240, 110920, 112600], [129235, 130960, 132685]],
    [[124570, 126880, 129190], [150415, 152770, 155125], [177160, 179560, 181960]]
])
with psum_file.open("w") as f:
    for c in range(4):
        for r in range(3):
            for col in range(3):
                f.write(fmt.format(psum[c, r, col]) + "\n")
