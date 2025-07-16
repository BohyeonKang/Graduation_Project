import numpy as np
import sys

# --- 🎯 목적 (Purpose) ---
# Row Stationary (RS) dataflow에 기반한 3D convolution 처리 흐름을 Python 코드로 정확하게 시뮬레이션 및 검증

# --- 🧠 처리 구조 및 파라미터 ---
IFMAP_H, IFMAP_W, IFMAP_C = 5, 5, 5  # Input Feature Map Size
FILTER_H, FILTER_W, FILTER_C_IN = 3, 3, IFMAP_C  # Filter Size (input channel matches ifmap channel)
OUTPUT_C = 4  # Number of output channels (also total number of filters)
OFMAP_H, OFMAP_W, OFMAP_C = IFMAP_H - FILTER_H + 1, IFMAP_W - FILTER_W + 1, OUTPUT_C  # Output Feature Map Size

# --- 📐 RS Dataflow 파라미터 ---
P_OUT_CHANNELS = OUTPUT_C  # p: filter 개수 = output channel
Q_IN_CHANNELS = IFMAP_C  # q: input channel
S_FILTER_WIDTH = FILTER_W  # s: filter width (1D window size)

# --- PE 및 PE Set 동작 정의 ---
# PE Set: 3x3 배열 (height = filter row 개수, width = ofmap row 개수)
# 각 PE는 1개의 1D convolution을 수행함
# PE는 다음 데이터를 처리함:
#   ifmap: 5채널 * 3값 = 15개 (1D row window)
#   weight: 4개의 output channel * 5채널 * 3값 = 60개
#   psum: output channel 4개에 대해 각각 누적

class PE:
    def __init__(self, pe_id):
        self.pe_id = pe_id
        # 모든 spad를 정수형으로 초기화
        self.ifmap_spad = np.zeros((Q_IN_CHANNELS, S_FILTER_WIDTH), dtype=int)  # q x s = 5x3 = 15
        self.weight_spad = np.zeros((P_OUT_CHANNELS, Q_IN_CHANNELS, S_FILTER_WIDTH), dtype=int) # p x q x s = 4x5x3 = 60
        self.psum_spad = np.zeros(P_OUT_CHANNELS, dtype=int)  # p = 4

    def load_ifmap_window(self, ifmap_window):
        """
        PE의 ifmap spad에 1D ifmap window (q x s)를 로드합니다.
        ifmap_window shape: (Q_IN_CHANNELS, S_FILTER_WIDTH)
        """
        self.ifmap_spad = ifmap_window.astype(int) # 로드 시 정수형으로 변환
        print(f"  PE {self.pe_id}: ifmap spad 로드 완료.")
        # 이전에 여기에 있던 ifmap spad 출력은 perform_1d_convolution으로 이동하여 통합됩니다.

    def load_weights(self, weights):
        """
        PE의 weight spad에 weight (p x q x s)를 로드합니다.
        weights shape: (P_OUT_CHANNELS, Q_IN_CHANNELS, S_FILTER_WIDTH)
        """
        self.weight_spad = weights.astype(int) # 로드 시 정수형으로 변환
        print(f"  PE {self.pe_id}: weight spad 로드 완료.")
        # 이전에 여기에 있던 weight spad 출력은 perform_1d_convolution으로 이동하여 통합됩니다.

    def perform_1d_convolution(self):
        """
        PE가 ifmap과 weight를 곱하고, 4개의 psum을 생성하여 psum spad에 저장합니다.
        RS dataflow에서 각 PE는 특정 출력 채널 그룹과 관련된 1D convolution을 수행합니다.
        여기서는 각 PE가 모든 출력 채널에 대한 1D convolution의 누적 합을 계산한다고 가정합니다.
        """
        # 1D Convolution 수행 전에 ifmap spad와 weight spad 내용을 출력합니다.
        print(f"  PE {self.pe_id}: 1D Convolution을 위한 ifmap spad (flattened):")
        # ifmap_spad (Q_IN_CHANNELS, S_FILTER_WIDTH)를 1차원으로 펼쳐서 출력
        print(f"  {self.ifmap_spad.flatten()}")

        print(f"  PE {self.pe_id}: 1D Convolution을 위한 weight spad (flattened per p-line):")
        # weight_spad (P_OUT_CHANNELS, Q_IN_CHANNELS, S_FILTER_WIDTH)를 각 출력 채널(p)별로 펼쳐서 출력
        for p_idx in range(P_OUT_CHANNELS):
            # Q_IN_CHANNELS x S_FILTER_WIDTH 부분을 펼치고 공백으로 연결하여 한 줄로 출력
            print(f"  [{' '.join(map(str, self.weight_spad[p_idx, :, :].flatten()))}]")

        self.psum_spad.fill(0) # psum 초기화
        for p_idx in range(P_OUT_CHANNELS):
            for q_idx in range(Q_IN_CHANNELS):
                for s_idx in range(S_FILTER_WIDTH):
                    # ifmap_spad[q_idx, s_idx]는 해당 채널/슬라이스 ifmap 값
                    # weight_spad[p_idx, q_idx, s_idx]는 해당 출력 채널/입력 채널/슬라이스 weight 값
                    self.psum_spad[p_idx] += self.ifmap_spad[q_idx, s_idx] * self.weight_spad[p_idx, q_idx, s_idx]
        print(f"  PE {self.pe_id}: 1D Convolution 수행 완료.")
        print(f"  PE {self.pe_id} psum spad: {self.psum_spad}")
        return self.psum_spad

# PE Set 생성
pe_set = [PE(i) for i in range(OFMAP_H * OFMAP_W)] # 3x3 = 9개의 PE

# --- 💾 GLB(Global Buffer) 구성 ---
class GLB:
    def __init__(self):
        # 모든 bank를 정수형으로 초기화 (내부적으로는 (H, W, C) 순서 유지)
        self.bank0_ifmap = np.zeros((IFMAP_H, IFMAP_W, IFMAP_C), dtype=int) # 5x5x5
        self.bank1_weights = np.zeros((OUTPUT_C, FILTER_C_IN, FILTER_H, FILTER_W), dtype=int) # 4x5x3x3
        self.bank2_psums = np.zeros((OFMAP_H, OFMAP_W, OFMAP_C), dtype=int) # 3x3x4

    def initialize_banks(self):
        # Bank0: ifmap 더미 데이터 (0부터 순차적으로 채움)
        # 숫자가 W (가장 빠르게), 그 다음 H, 그 다음 C (가장 느리게) 채워지도록 합니다.
        # 따라서, (C, H, W) 모양으로 재구성한 다음 (H, W, C)로 전치(transpose)합니다.
        self.bank0_ifmap = np.arange(IFMAP_C * IFMAP_H * IFMAP_W).reshape(IFMAP_C, IFMAP_H, IFMAP_W).transpose(1, 2, 0).astype(int)
        print("\n--- GLB Bank0 (ifmap) 초기화 완료 (채널별 시각화) ---")
        for c in range(IFMAP_C):
            print(f"--- ifmap Channel {c} ---")
            print(self.bank0_ifmap[:, :, c])


        # Bank1: weights 더미 데이터 (1 단위로 순차적으로 채움)
        # 이 부분은 각 커널 슬라이스(IC, OC 내 H, W) 내에서 이미 행 우선 순서로 채워져 있습니다.
        self.bank1_weights = np.arange(OUTPUT_C * FILTER_C_IN * FILTER_H * FILTER_W).reshape(OUTPUT_C, FILTER_C_IN, FILTER_H, FILTER_W).astype(int)
        print("\n--- GLB Bank1 (weights) 초기화 완료 (필터별/채널별 시각화) ---")
        # weights를 필터별로, 각 필터 내에서 채널별로 시각화
        for oc in range(OUTPUT_C): # 출력 채널 (필터) 별 구분
            print(f"\n--- Weight for Output Filter {oc} ---")
            for ic in range(FILTER_C_IN): # 각 필터 내에서 입력 채널 별 구분
                print(f"--- Input Channel {ic} Kernel ---")
                print(self.bank1_weights[oc, ic, :, :]) # (FILTER_H, FILTER_W)


        # Bank2: psums는 초기화 불필요 (연산 결과가 누적됨)
        print("\n--- GLB Bank2 (psums) 초기화 불필요 (0으로 유지) ---")
        # 초기 psum은 0으로 표시 (채널별/행별 시각화)
        for oc in range(OFMAP_C):
            print(f"--- psum Output Channel {oc} ---")
            for row_idx in range(OFMAP_H): # 행별 시각화 적용
                print(f"Output Row {row_idx}: {self.bank2_psums[row_idx, :, oc]}")

    def store_psum_to_bank2(self, psums, ofmap_row, ofmap_col):
        """
        PE의 psum spad 결과를 GLB Bank2에 저장합니다.
        ofmap_row, ofmap_col은 현재 PE가 처리하는 출력 feature map의 위치입니다.
        """
        # 이 부분이 중요: 기존 값을 덮어쓰는 것이 아니라 누적합니다.
        self.bank2_psums[ofmap_row, ofmap_col, :] += psums.astype(int) 
        print(f"  GLB Bank2에 psum 저장 완료 (위치: [{ofmap_row},{ofmap_col}]).")
        
        print("  업데이트된 GLB Bank2 (누적 결과):")
        for oc in range(OFMAP_C):
            print(f"--- psum Output Channel {oc} ---")
            for row_idx in range(OFMAP_H): # 행별 시각화 적용
                print(f"Output Row {row_idx}: {self.bank2_psums[row_idx, :, oc]}")


glb = GLB()

# --- 🧪 코드가 수행해야 할 작업 ---

output_filename = "convolution_simulation_output.txt"
original_stdout = sys.stdout # 원본 stdout 저장

try:
    with open(output_filename, 'w') as f:
        sys.stdout = f # stdout을 파일로 리다이렉션

        print("--- RS Dataflow 기반 3D Convolution 검증 시뮬레이션 시작 ---")

        # 📌 단계별 동작 순서

        # 1. GLB 초기화
        glb.initialize_banks()

        # PE Set에 Weight 로드 (한번 로드하면 시뮬레이션 내내 재사용)
        # 각 PE의 'row' 인덱스 (pe_idx // OFMAP_W)에 따라 해당 필터 행의 가중치를 로드합니다.
        print("\n--- PE Weight Loading (초기 1회, PE Array 행에 따라) ---")
        for pe_idx in range(len(pe_set)):
            # PE Array 내에서의 행 인덱스 (0, 1, 2)
            pe_row_in_array = pe_idx // OFMAP_W 
            # 이 PE Array 행에 해당하는 필터 행의 가중치를 로드
            current_weight_slice = glb.bank1_weights[:, :, pe_row_in_array, :].astype(int) 
            pe_set[pe_idx].load_weights(current_weight_slice)


        # Output Feature Map의 행(ofmap_row_idx)을 순회합니다.
        # 각 ofmap_row_idx 마다 PE Array가 input feature map의 새로운 행 슬라이스를 처리합니다.
        for ofmap_row_idx in range(OFMAP_H):
            print(f"\n===== 현재 Processing Pass: Output Row {ofmap_row_idx} =====")

            # Output Feature Map의 열(ofmap_col_idx)을 순회합니다.
            # 각 ofmap_col_idx 마다 해당 PE가 활성화되어 연산을 수행합니다.
            for ofmap_col_idx in range(OFMAP_W):
                print(f"\n--- Processing PE at Output Position: ({ofmap_row_idx}, {ofmap_col_idx}) ---")

                # 현재 (ofmap_row_idx, ofmap_col_idx)에 해당하는 출력을 계산할 PE를 선택합니다.
                # 이 PE는 PE Array 내에서 (담당 필터 행, 담당 출력 열) 위치에 해당합니다.
                current_pe = pe_set[(ofmap_row_idx * OFMAP_W) + ofmap_col_idx]
                
                # ifmap 윈도우 로드
                # ifmap_window_row: 현재 출력 행 (ofmap_row_idx)과 PE가 담당하는 필터 행 (current_pe.pe_id // OFMAP_W)의 합
                current_ifmap_window_row = ofmap_row_idx + (current_pe.pe_id // OFMAP_W)
                current_ifmap_window_col = ofmap_col_idx

                ifmap_window_for_pe = glb.bank0_ifmap[
                    current_ifmap_window_row,
                    current_ifmap_window_col : current_ifmap_window_col + S_FILTER_WIDTH,
                    : # 모든 채널
                ].T.astype(int)

                current_pe.load_ifmap_window(ifmap_window_for_pe)

                # 연산 수행 (MAC)
                current_psums = current_pe.perform_1d_convolution()

                # GLB Bank2에 psum 누적 저장
                glb.store_psum_to_bank2(current_psums, ofmap_row_idx, ofmap_col_idx)

        # 최종 GLB Bank2 (output feature map) 출력
        print("\n--- 최종 GLB Bank2 (Output Feature Map) (채널별/행별 시각화) ---")
        # psum도 채널별 시각화
        for oc in range(OFMAP_C):
            print(f"--- Final Output Channel {oc} ---")
            for row_idx in range(OFMAP_H): # 행별 시각화 적용
                print(f"Output Row {row_idx}: {glb.bank2_psums[row_idx, :, oc]}")

        print("\n--- 시뮬레이션 완료 ---")

finally:
    sys.stdout = original_stdout # stdout을 원래대로 복원

print(f"시뮬레이션 출력이 '{output_filename}' 파일로 저장되었습니다.")