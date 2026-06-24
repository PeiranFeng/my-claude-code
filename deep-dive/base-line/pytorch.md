# PyTorch Primitives

## torch.einsum

```python
torch.einsum(equation: str, *operands: Tensor) -> Tensor
```

用字符串描述张量操作：`"输入标签->输出标签"`，每个维度分配一个字母。操作分两步：① 对所有维度组合逐元素相乘；② 沿不出现在输出标签中的维度求和。`...` 表示任意批量维度，透传到输出。

**Last mentioned**: 2026-06-24
