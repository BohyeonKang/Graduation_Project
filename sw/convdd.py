import torch
import torch.nn.functional as F

N = 1
M = 4
C = 5
H = W = 5
R = S = 3

ifmap = torch.arange(N * C * H * W, dtype=torch.float32).reshape(N, C, H, W)
wght = torch.arange(M * C * R * S, dtype=torch.float32).reshape(M, C, R, S)

# 컨볼루션 수행 (stride=1, padding=0)
output = F.conv2d(ifmap, wght, bias=None, stride=1, padding=0)

print(output)