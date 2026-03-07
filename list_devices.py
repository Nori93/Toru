import torch_directml

devices = torch_directml.device_count()

print("DirectML device count:", devices)

for i in range(devices):
    device = torch_directml.device(i)
    print(f"Device {i}:", device)