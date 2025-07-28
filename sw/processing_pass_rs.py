import torch

def process_sequential_data(N: int, C: int, H: int, W: int, window_size: int):
    """
    주어진 N, C, H, W 값과 윈도우 크기를 사용하여 텐서를 생성하고
    슬라이싱 작업을 반복문으로 수행합니다. 각 슬라이싱 결과는 1D 벡터로 출력됩니다.

    Args:
        N (int): 배치(Batch) 크기
        C (int): 채널(Channel) 크기
        H (int): 높이(Height) 크기
        W (int): 너비(Width) 크기
        window_size (int): 슬라이싱할 윈도우 크기
    """
    if window_size > W:
        raise ValueError("window_size는 W보다 클 수 없습니다.")

    input_feature_map = N * C * H * W

    # 0부터 input_feature_map - 1까지 순차적으로 증가하는 1D 텐서 생성
    sequential_data_1d = torch.arange(input_feature_map, dtype=torch.int32)

    # N*C*H*W 형태로 재구성
    sequential_data_NCHW = sequential_data_1d.view(N, C, H, W)

    # 결과를 저장할 딕셔너리
    results = {}

    # 반복문을 사용하여 슬라이싱 작업 수행
    for iter_idx in range(W - window_size + 1):
        for row_idx in range(H):
            key = f"ROW{row_idx}_iter{iter_idx}"
            # 슬라이싱된 텐서를 1D로 평탄화 (flatten)
            sliced_tensor_1d = sequential_data_NCHW[0, :, row_idx, iter_idx : iter_idx + window_size].flatten()
            results[key] = sliced_tensor_1d
            print(f"{key}: {results[key]}")

    return results

# 함수 사용 예시
N_val = 1
C_val = 5
H_val = 5
W_val = 5
window_size_val = 3

sliced_data = process_sequential_data(N_val, C_val, H_val, W_val, window_size_val)