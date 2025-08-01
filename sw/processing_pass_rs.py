import torch

def ifmap_load_addr_gen(N: int, C: int, H: int, W: int, S: int, U: int, Pad: int):
    """
    N, C, H, W: ifmap shape
    S: filter width (가로)
    U: stride
    Pad: padding
    반환: torch.Tensor of shape (E, R, C*S)
    """
    E = ((H - S + 2*Pad) // U) + 1  # 출력 feature map row 수

    # ifmap shape: (N, C, H, W)
    ifmap = torch.arange(N * C * H * W, dtype=torch.int32).view(N, C, H, W)

    result_tensor = torch.zeros((E, H, C * S), dtype=torch.int32)

    for e in range(E):        # output row index
        for r in range(H):    # input row index
            patch = ifmap[0, :, r, e : e + S].flatten()  # shape: (C*S,)
            result_tensor[e, r] = patch

    return result_tensor

def wght_load_addr_gen(M: int, C: int, R: int, S: int):
    """
    M: output channel 개수 (filter 개수)
    C: input channel 개수
    R: filter height (row 방향 size)
    S: filter width (col 방향 size)
    
    Returns:
        Tensor of shape (R, M, C*S)
    """
    wght = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)
    
    result_tensor = torch.zeros((R, M, C * S), dtype=torch.int32)

    for r in range(R):
        # 각 row에서 슬라이싱한 결과: shape (M, C*S)
        row_slice = wght[:, :, r, :].reshape(M, C * S)
        result_tensor[r] = row_slice

    return result_tensor  # shape: (R, M, C*S)

def PE_1dconv(ifmap_row: torch.Tensor, weights: torch.Tensor, p, q, s):
    """
    ifmap: torch.Tensor of shape (q*s,)
    weights: torch.Tensor of shape (p, q*s)
    """
    expected_ifmap_len = q * s
    if len(ifmap_row) != expected_ifmap_len:
        raise ValueError(f"ifmap_row의 길이는 q * s ({expected_ifmap_len})와 같아야 하지만, 실제 길이는 {len(ifmap_row)}입니다.")

    if weights.ndim != 2:
        raise ValueError(f"weights는 2차원 배열이어야 하지만, 실제 차원은 {weights.ndim}입니다.")
    if weights.shape[0] != p:
        raise ValueError(f"weights 배열의 행 수는 p ({p})와 같아야 하지만, 실제 행 수는 {weights.shape[0]}입니다.")
    if weights.shape[1] != expected_ifmap_len:
        raise ValueError(f"weights 배열의 열 수는 q * s ({expected_ifmap_len})와 같아야 하지만, 실제 열 수는 {weights.shape[1]}입니다.")

    acc_results = torch.matmul(weights, ifmap_row)  # shape: (p,)

    return acc_results

import torch

class PE:
    def __init__(self):
        self.ifmap_row = None     # shape: (C*S,)
        self.weight_row = None    # shape: (M, C*S)
        self.psum_out = None      # shape: (M,)

    def load_ifmap(self, ifmap_row: torch.Tensor):
        self.ifmap_row = ifmap_row

    def load_weight(self, wght_row: torch.Tensor):
        self.weight_row = wght_row

    def compute(self):
        if self.ifmap_row is None or self.weight_row is None:
            raise ValueError("ifmap 또는 weight가 로드되지 않았습니다.")
        self.psum_out = torch.matmul(self.weight_row, self.ifmap_row)  # shape: (M,)

    def accumulate(self, psum_in: torch.Tensor):
        if self.psum_out is None:
            raise ValueError("먼저 compute()를 수행해야 합니다.")
        self.psum_out += psum_in

    def get_result(self) -> torch.Tensor:
        if self.psum_out is None:
            raise ValueError("아직 결과가 계산되지 않았습니다.")
        return self.psum_out

# Convoluation parameter setting
N = 1
M = 4
C = 5
H = W = 5
R = S = 3
U = 1
Pad = 0

ifmap_ra = ifmap_load_addr_gen(N, C, H, W, S, U, Pad)
wght_ra = wght_load_addr_gen(M, C, R, S)

wght_CONV_ra_rows = wght_conv_addr_gen(M, C, R, S)

ifmap_mem = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)
wght_mem = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)

#psum_res = PE_1dconv(ifmap_ra, wght_ra, M, C, S)

print(wght_ra[0])
        
print("파일 저장 완료")