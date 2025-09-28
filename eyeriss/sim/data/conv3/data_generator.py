import torch
import torch.nn.functional as F

class Conv2DMemExporter:
    def __init__(self, N=1, C_in=4, H=15, W=15, C_out=16, K=3):
        self.N, self.C_in, self.H, self.W = N, C_in, H, W
        self.C_out, self.K = C_out, K
        self.input_tensor = torch.arange(0, N*C_in*H*W).float().reshape(N, C_in, H, W)
        self.weight_tensor = torch.arange(0, C_out*C_in*K*K).float().reshape(C_out, C_in, K, K)
        self.output_tensor = F.conv2d(self.input_tensor, self.weight_tensor, bias=None, stride=1, padding=0)

    def export_psum_answer(self, filename="psum_answer.mem"):
        output_flat = self.output_tensor.flatten()
        with open(filename, "w") as f:
            for val in output_flat:
                uint_val = int(val.item()) & 0xFFFFFFFF
                f.write(f"{uint_val:X}\n")

    def export_psum_init(self, filename="psum_init.mem"):
        output_flat = self.output_tensor.flatten()
        with open(filename, "w") as f:
            for _ in output_flat:
                f.write("0\n")

    def export_ifmap(self, filename="ifmap.mem"):
        input_flat = self.input_tensor.flatten()
        with open(filename, "w") as f:
            for val in input_flat:
                uint_val = int(val.item()) & 0xFFFFFFFF
                f.write(f"{uint_val:X}\n")

    def export_weight(self, filename="weight.mem"):
        weight_flat = self.weight_tensor.flatten()
        with open(filename, "w") as f:
            for val in weight_flat:
                uint_val = int(val.item()) & 0xFFFFFFFF
                f.write(f"{uint_val:X}\n")


# 'conv3' for Alexnet Conv3, 'conv4_5' for Alexnet Conv4,5
conv_layer_to_export = 'conv3'


# Update parameters based on the selected layer
if conv_layer_to_export == 'conv3':
    N=1, C_in=4, H=15, W=15, C_out=16, K=3
elif conv_layer_to_export == 'conv4_5':
    N=1, C_in=3, H=15, W=15, C_out=16, K=3
else:
    # Handle an invalid selection, e.g., by raising an error or setting a default.
    raise ValueError("Invalid convolution layer specified. Choose 'conv3' or 'conv4_5'.")

exporter = Conv2DMemExporter(N=N, C_in=C_in, H=H, W=W, C_out=C_out, K=K)
exporter.export_psum_answer()
exporter.export_psum_init()
exporter.export_ifmap()
exporter.export_weight()

# Default parameters correspond to:
# Alexnet Conv3 : N=1, C_in=4, H=15, W=15, C_out=16, K=3 (padded size)
# Alexnet Conv4,5 : N=1, C_in=3, H=15, W=15, C_out=16, K=3 (padded size)