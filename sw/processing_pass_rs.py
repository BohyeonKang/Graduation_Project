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
    ifmap_addr_range = torch.arange(N * C * H * W, dtype=torch.int32).view(N, C, H, W)

    result_tensor = torch.zeros((E, H, C * S), dtype=torch.int32)

    for e in range(E):        # output row index
        for r in range(H):    # input row index
            patch = ifmap_addr_range[0, :, r, e : e + S].flatten()  # shape: (C*S,)
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
    wght_addr_range = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)
    
    result_tensor = torch.zeros((R, M, C * S), dtype=torch.int32)

    for r in range(R):
        # 각 row에서 슬라이싱한 결과: shape (M, C*S)
        row_slice = wght_addr_range[:, :, r, :].reshape(M, C * S)
        result_tensor[r] = row_slice

    return result_tensor  # shape: (R, M, C*S)

class PE:
    def __init__(self):
        self.ifmap_row = None     # shape: (C*S,)
        self.weight_row = None    # shape: (M, C*S)
        self.psum_in = None       # shape: (M,)?
        self.psum_out = None      # shape: (M,)

    def load_ifmap(self, ifmap_row: torch.Tensor):
        self.ifmap_row = ifmap_row

    def load_weight(self, wght_row: torch.Tensor):
        self.weight_row = wght_row
        
    def load_psum(self, psum_in: torch.Tensor):
        self.psum_in = psum_in

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

# 주소 생성기 호출
ifmap_ra = ifmap_load_addr_gen(N, C, H, W, S, U, Pad)
wght_ra = wght_load_addr_gen(M, C, R, S)

# 실제 메모리 데이터 (예시, 위에 정의된 것과 동일)
# PE에 로드할 데이터가 들어있는 실제 메모리를 시뮬레이션
ifmap_mem = torch.arange(N * C * H * W, dtype=torch.int32).view(N, C, H, W)
wght_mem = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)

# PE 객체 선언
pe1 = PE()

# 예시: ifmap_ra의 첫 번째 행과 wght_ra의 첫 번째 행을 사용하여 데이터 로드 및 연산
# (E, R, C*S) -> (0, 0, :) 로 첫 번째 ifmap row를 가져옵니다.
ifmap_data_to_load = ifmap_mem.flatten()[ifmap_ra[0, 0]]
# (R, M, C*S) -> (0, :, :) 로 첫 번째 weight row를 가져옵니다.
wght_data_to_load = wght_mem.flatten()[wght_ra[0, :]]

print("ifmap_data_to_load shape:", ifmap_data_to_load.shape)
print("wght_data_to_load shape:", wght_data_to_load.shape)