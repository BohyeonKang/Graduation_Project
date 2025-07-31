import torch

def ifmap_load_addr_gen(N: int, C: int, H: int, W: int, S: int, U: int, Pad:int):
    
    E = ((H - S + 2*Pad) // U) + 1

    # 0부터 input_feature_map - 1까지 순차적으로 증가하는 1D 텐서 생성 및 N*C*H*W 형태로 재구성
    ifmap = torch.arange(N * C * H * W, dtype=torch.int32).view(N, C, H, W)

    results = {}

    for iter_idx in range(E):
        for row_idx in range(H):
            key = f"iter{iter_idx}_ROW{row_idx}"
            # 슬라이싱된 텐서를 1D로 평탄화 (flatten)
            ifmap_row_slice = ifmap[0, :, row_idx, iter_idx : iter_idx + S].flatten()
            results[key] = ifmap_row_slice

    return results

def wght_load_addr_gen(M: int, C: int, R: int, S: int):
    
    wght = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)

    results = {}

    # 반복문을 사용하여 슬라이싱 작업 수행
    for cnt_R in range(R):
        key = f"ROW{cnt_R}"
        # 슬라이싱된 텐서를 1D로 평탄화 (flatten)
        wght_row_slice = wght[:, :, cnt_R, :].reshape(M, C * S)
        results[key] = wght_row_slice

    return results

def wght_conv_addr_gen(M: int, C: int, R: int, S: int):

    wght = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)

    results = {}

    # 반복문을 사용하여 슬라이싱 작업 수행
    for cnt_R in range(R):
        key = f"ROW{cnt_R}"
        # 슬라이싱된 텐서를 1D로 평탄화 (flatten)
        wght_row_slice = wght[:, :, cnt_R , :].permute(1,2,0).flatten()
        results[key] = wght_row_slice

    return results

def read_from_memory_by_ra(memory_tensor: torch.Tensor, ra_dict: dict) -> dict:
    """
    memory_tensor: shape (M, C, R, S)
    ra_dict: dictionary mapping keys to index tensors (flattened addresses)
    
    Returns:
        new_dict: dictionary with same keys, values are actual data from memory
    """
    # Flatten the memory for 1D indexing
    flat_mem = memory_tensor.flatten()
    
    result = {}
    for key in ra_dict:
        addr_tensor = ra_dict[key]  # e.g., shape (15,)
        result[key] = flat_mem[addr_tensor]  # indexing
    return result

N = 1
M = 4

C = 5

H = 5
W = 5

R = 3
S = 3

U = 1
Pad = 0

ifmap_rows = ifmap_load_addr_gen(N, C, H, W, S, U, Pad)
wght_rows = wght_load_addr_gen(M, C, R, S)
wght_CONV_ra_rows = wght_conv_addr_gen(M, C, R, S)


wght_mem = torch.arange(M * C * R * S, dtype=torch.int32).view(M, C, R, S)


#wght_rows_data = read_from_memory_by_ra(wght_mem, wght_ra_rows)

# 결과를 txt 파일로 저장
with open("ifmap_rows_output.txt", "w") as f:
    for key in ifmap_rows:
        hex_values = [f"{v:#010x}" for v in ifmap_rows[key].tolist()]
        f.write(f"{key} : {hex_values}\n")
        
with open("wght_rows_output.txt", "w") as f:
    for key in wght_rows:
        f.write(f"{key}:\n")
        for row in wght_rows[key]:
            hex_values = [f"{v.item():#010x}" for v in row]
            f.write("  " + str(hex_values) + "\n")

print("파일 저장 완료")