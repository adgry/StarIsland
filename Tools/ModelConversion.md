模型转换与集成说明
===================================

本文档说明如何将 PyTorch / ONNX / TensorFlow 人脸识别模型转换为 Core ML 格式，以及本应用通用加载器在运行时兼容性方面所期望的模型规范。

推荐评估的模型：
- MobileFaceNet（速度快、体积小）
- 基于 ResNet-50 的现代骨干网络（识别精度高）
- MagFace-small（速度与精度均衡）

转换规范与指南
---------------------
- 尽可能优先转换为 Core ML Program（`mlpackage`）格式（即指定 `convert_to='mlprogram'`），以获得更佳的运行时推理性能。
- `MLModelManager` 中的运行时加载器要求模型接收单个多维数组（MultiArray）作为输入，并输出单个包含特征嵌入向量（Embedding Vector）的多维数组。

输入/输出命名约定
- 输入（Input）：默认读取模型的第一个输入张量。为简洁起见，建议在导出时将输入张量命名为 `input`。
- 输出（Output）：加载器默认读取模型返回的第一个输出张量。为清晰起见，建议将输出命名为 `embeddings` 或类似名称。

FP16 / INT8 量化说明
- 建议优先尝试 FP16 半精度量化（对精度影响较小）：

  ```py
  import coremltools as ct
  mlmodel = ct.convert('model.pt', inputs=[ct.TensorType(shape=(1,3,112,112))], convert_to='mlprogram')
  spec = mlmodel.get_spec()
  fp16_spec = ct.models.neural_network.quantization_utils.convert_neural_network_spec_weights_to_fp16(spec)
  ct.models.MLModel(fp16_spec).save('ModernFace_fp16.mlpackage')
  ```

- 如果你需要进一步缩减模型体积，且愿意测试并评估潜在的精度损失，可以尝试 8 位线性量化（INT8）。

数值校验
----------
完成转换后，请在一小批测试输入样本上进行数值比对校验（对比 PyTorch / TensorFlow 原始输出与 Core ML 转换后输出），确保不存在显著的数值偏差或精度退化。

运行时部署说明
-------------
- 将编译后的 `.mlmodelc` 或 `.mlpackage` 模型文件命名为 `ModernFace`，并放入应用包（App Bundle）的 Resources 资源目录中。
- 应用在运行时会自动加载 `ModernFace.mlmodelc` 或 `ModernFace.mlmodel`，这是当前唯一受支持的模型文件名称。

转换脚本示例可参考同目录下的 `convert_to_coreml.py`（模板文件）。
